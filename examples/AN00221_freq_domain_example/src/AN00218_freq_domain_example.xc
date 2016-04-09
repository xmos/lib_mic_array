// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include "mic_array.h"

#include "lib_dsp.h"

#include "i2c.h"
#include "i2s.h"

#include "xscope.h"

#define DSP_ENABLED 1
#define INPUT_FROM_HW 1
// MIC_ARRAY_WORD_LENGTH_SHORT 0 defined in mic_array_conf.h


#define DECIMATION_FACTOR   2   //Corresponds to a 48kHz output sample rate
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define NUM_FRAME_BUFFERS   3   //Triple buffer needed for overlapping frames

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

out buffered port:32 p_i2s_dout[1]  = on tile[1]: {XS1_PORT_1P};
in port p_mclk_in1                  = on tile[1]: XS1_PORT_1O;
out buffered port:32 p_bclk         = on tile[1]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[1]: XS1_PORT_1N;
port p_i2c                          = on tile[1]: XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA
port p_rst_shared                   = on tile[1]: XS1_PORT_4F; // Bit 0: DAC_RST_N, Bit 1: ETH_RST_N
clock mclk                          = on tile[1]: XS1_CLKBLK_3;
clock bclk                          = on tile[1]: XS1_CLKBLK_4;



#define FFT_N (1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2)

int data[8][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

#define NUM_SIGNAL_ARRAYS MIC_ARRAY_NUM_MICS/2

#define NUM_OUTPUT_CHANNELS 2

typedef struct {
    int32_t data[NUM_OUTPUT_CHANNELS][FFT_N/2]; // FFT_N/2 due to overlapping
} multichannel_audio_block_s;


/**
 The interface between the two tasks is a single transaction that get_next_bufs
 the movable pointers. It has an argument that is a reference to a
 movable pointer. Since it is a reference the server side of the
 connection can update the argument.
*/

interface bufget_i {
  void get_next_buf(multichannel_audio_block_s * unsafe &buf);
};

// make global to enforce 64 bit alignment
multichannel_audio_block_s triple_buffer[3];


int your_favourite_window_function(unsigned i, unsigned window_length){
    //Hanning function takes 10k memory which blows up the memory with FFT_N 4k
    //TODO: Optimise using lib_dsp_math_sqrt and lib_dsp_math_cos.
    //Hanning window
    //return((int)((double)INT_MAX*sqrt(0.5*(1.0 - cos(2.0 * 3.14159265359*(double)i / (double)(window_length-2))))));

    //Rectangular
    return INT_MAX;
}

void generate_audio_data(lib_dsp_fft_complex_t buffer[FFT_N]) {
  // points per cycle. divide by power of two to ensure signals fit into the FFT window
  const int32_t ppc = 64;  // 750 Hz at 48kHz Fs 
  //printf("Points Per Cycle is %d\n", ppc);
  for(int32_t i=0; i<FFT_N; i++) {
    // generate input signals

    // Equation: x = 2pi * i/ppc = 2pi * ((i%ppc) / ppc))
    q8_24 factor = ((i%ppc) << 24) / ppc; // factor is always < Q24(1)
    q8_24 x = lib_dsp_math_multiply(PI2_Q8_24, factor, 24);

    buffer[i].re = lib_dsp_math_sin(x);
    //buffer[i].im = 0;
    buffer[i].im = lib_dsp_math_cos(x);

  }
}


void freq_domain_example(streaming chanend c_ds_output[2], streaming chanend c_audio){

    unsigned buffer ;
    mic_array_frame_fft_preprocessed comp[NUM_FRAME_BUFFERS];

    memset(data, 0, sizeof(int)*8*THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR);

    int window[FFT_N/2];
    for(unsigned i=0;i<FFT_N/2;i++)
         window[i] = your_favourite_window_function(i, FFT_N);

    unsafe{
        mic_array_decimator_conf_common_t dcc = {
                MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
                1,
                DSP_ENABLED, // bit reverse buffer if 1
                window,
                DECIMATION_FACTOR,
                g_third_stage_div_2_fir,
                0,
                FIR_COMPENSATOR_DIV_2,
                DECIMATOR_HALF_FRAME_OVERLAP,
                NUM_FRAME_BUFFERS
        };

        mic_array_decimator_config_t dc[2] = {
                {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        mic_array_decimator_configure(c_ds_output, 2, dc);

        mic_array_init_frequency_domain_frame(c_ds_output, 2, buffer, comp, dc);

        while(1){

            lib_dsp_fft_complex_t p[FFT_N]; // use as tmp buffer as well as output buffer

#if INPUT_FROM_HW
            //Recieve the preprocessed frames ready for the FFT
            mic_array_frame_fft_preprocessed * current = mic_array_get_next_frequency_domain_frame(c_ds_output, 2, buffer, comp, dc);

#if DSP_ENABLED
           for(unsigned i=0;i<MIC_ARRAY_NUM_FREQ_CHANNELS;i++){
#if MIC_ARRAY_WORD_LENGTH_SHORT
               // convert current->data[i] into p
               lib_dsp_fft_short_to_long(p, (lib_dsp_fft_complex_short_t*)current->data[i], FFT_N); 
               //Apply one FFT to two channels at a time
               lib_dsp_fft_forward(p, FFT_N, lib_dsp_sine_512);
               //Reconstruct the two independent frequency domain representations
               lib_dsp_fft_split_spectrum(p, FFT_N);
               // convert p back into current->data[i]
               lib_dsp_fft_long_to_short((lib_dsp_fft_complex_short_t*)current->data[i], p, FFT_N); 
#else
               //Apply one FFT to two channels at a time
               lib_dsp_fft_forward((lib_dsp_fft_complex_t*)current->data[i], FFT_N, lib_dsp_sine_512);

               //Reconstruct the two independent frequency domain representations
               lib_dsp_fft_split_spectrum((lib_dsp_fft_complex_t*)current->data[i], FFT_N);
#endif
           }
           mic_array_frame_frequency_domain * frequency = (mic_array_frame_frequency_domain*)current;


/*
           //Work in the frequency domain here
           //For example, low pass filter of channel 0
           //cut off: (Fs/FFT_N * 30) Hz = (48000/512*30) Hz = 2812.5Hz
           for(unsigned i = 30; i < FFT_N/2; i++){
               frequency->data[0][i].re = 0;
               frequency->data[0][i].im = 0;
           }
           //Don't forget the nyquest rate
           frequency->data[0][0].im = 0;


           //For example, high pass filter of channel 1
           //cut off: (Fs/FFT_N * 30) Hz = (48000/512*30) Hz = 2812.5Hz
           frequency->data[1][0].re = 0.0;
           for(unsigned i = 1; i < 30; i++){
               frequency->data[1][i].re = 0;
               frequency->data[1][i].im = 0;
           }
*/

           //Now to get channel 0 and channel 1 back to the time domain=
#if MIC_ARRAY_WORD_LENGTH_SHORT
           // Note! frequency is an alias of current. current->data[0] has frequency->data[0] and frequency->data[1]
           // So we can convert directly into p
           lib_dsp_fft_short_to_long(p, (lib_dsp_fft_complex_short_t*)current->data[0], FFT_N); // convert into tmp buffer
#else
           memcpy(&p[0],       frequency->data[0], sizeof(lib_dsp_fft_complex_t)*FFT_N/2);
           memcpy(&p[FFT_N/2], frequency->data[1], sizeof(lib_dsp_fft_complex_t)*FFT_N/2);
#endif

           lib_dsp_fft_merge_spectra(p, FFT_N);
           lib_dsp_fft_bit_reverse(p, FFT_N);
           lib_dsp_fft_inverse(p, FFT_N, lib_dsp_sine_512);
           //Now the p array is a time domain representation of the selected channel.
           //   -The imaginary component will be the channel 1 time domain representation.
           //   -The real component will be the channel 0 time domain representation.


           //apply the window function
           for(unsigned i=0;i<FFT_N/2;i++){
              long long t = (long long)window[i] * (long long)p[i].re;
              p[i].re = (t>>31);
              t = (long long)window[i] * (long long)p[i].im;
              p[i].im = (t>>31);
           }
           for(unsigned i=FFT_N/2;i<FFT_N;i++){
              long long t = (long long)window[FFT_N-1-i] * (long long)p[i].re;
              p[i].re = (t>>31);
              t = (long long)window[FFT_N-1-i] * (long long)p[i].im;
              p[i].im = (t>>31);
           }
#else
// pass the data on unmodified           
#if MIC_ARRAY_WORD_LENGTH_SHORT
           // Note! frequency is an alias of current. current->data[0] has frequency->data[0] and frequency->data[1]
           // So we can convert directly into p
           lib_dsp_fft_short_to_long(p, (lib_dsp_fft_complex_short_t*)current->data[0], FFT_N); // convert into tmp buffer
#else
           memcpy(&p[0],       current->data[0], sizeof(lib_dsp_fft_complex_t)*FFT_N);
           //memcpy(&p[FFT_N/2], frequency->data[1], sizeof(lib_dsp_fft_complex_t)*FFT_N/2);
#endif
#endif
#else
           generate_audio_data(p);
#endif

#if PARTIALLY_UNROLLED
           for(unsigned i=0; i<FFT_N / 8 ; i+=8) { // partially unrolled loop
             c_audio <: p[i].re;
             c_audio <: p[i].im;
             c_audio <: p[i+1].re;
             c_audio <: p[i+1].im;
             c_audio <: p[i+2].re;
             c_audio <: p[i+2].im;
             c_audio <: p[i+3].re;
             c_audio <: p[i+3].im;
             c_audio <: p[i+4].re;
             c_audio <: p[i+4].im;
             c_audio <: p[i+5].re;
             c_audio <: p[i+5].im;
             c_audio <: p[i+6].re;
             c_audio <: p[i+6].im;
             c_audio <: p[i+7].re;
             c_audio <: p[i+7].im;
           }
#else
           for(unsigned i=0; i<FFT_N ; i++) {
             c_audio <: p[i].re; // output channel 0
             c_audio <: p[i].im; // output channel 1
           }
#endif
        }
    }
}


void output_audio_dbuf_handler(server interface bufget_i input,
        multichannel_audio_block_s triple_buffer[3],
        streaming chanend c_audio) {

  unsigned count = 0, sample_idx = 0, buffer_full=0;
  //unsigned buffer_get_next_bufped_flag=1;
  int32_t sample;

  unsigned head = 0;          //Keeps track of index of proc_buffer

unsafe {
  while (1) {
    // get_next_buf buffers
    select {
      case input.get_next_buf(multichannel_audio_block_s * unsafe &buf):
        // pass ptr to previous buffer
        if(head==0) {
          buf = &triple_buffer[NUM_FRAME_BUFFERS-1];
        } else {
          buf = &triple_buffer[head-1];
        }
        //buffer_get_next_bufped_flag = 1;
        buffer_full = 0;
        break;

      // guarded select case will create back pressure.
      // I.e. c_audio will block until buffer is get_next_bufped
      case !buffer_full => c_audio :> sample:
        //if(sample_idx == 0 && !buffer_get_next_bufped_flag) {
           //printf("Buffer overflow\n");
        //};
        unsigned channel_idx = count & 1;
        if(sample_idx<FFT_N/2) {
          // first half
          triple_buffer[head].data[channel_idx][sample_idx] += sample;
          //buffer->data[channel_idx][sample_idx] = sample;
        } else {
          // second half
          triple_buffer[(head+1)%NUM_FRAME_BUFFERS].data[channel_idx][sample_idx-(FFT_N/2)] = sample;
        }
        //buffer->data[channel_idx][sample_idx] = sample;
        if(channel_idx==1) {
          sample_idx++;
        }
        if(sample_idx>=FFT_N) {
          sample_idx = 0;
          buffer_full = 1;
          //Manage overlapping buffers
          head++;
          if(head == NUM_FRAME_BUFFERS)
              head = 0;
        }

        count++;

/*
           //Recombine the time domain frame from overlapping output frames from windowed iFFT result
           for(unsigned i=0;i<FFT_N / 2;i++){
               proc_buffer[0][head][i] += p[i].re;
               proc_buffer[0][(head+1)%NUM_FRAME_BUFFERS][i] = p[i+FFT_N/2].re;
               proc_buffer[1][head][i] += p[i].im;
               proc_buffer[1][(head+1)%NUM_FRAME_BUFFERS][i] = p[i+FFT_N/2].im;
           }

           // Send the audio data to another task for outputting over
           for(unsigned i=0; i<FFT_N / 2 ; i++) {
             c_audio <: proc_buffer[0][head][i];
             c_audio <: proc_buffer[1][head][i];
           }


                     head++;
          if(head == NUM_FRAME_BUFFERS)
              head = 0;

*/

        break;
    }
  }
}
}

void init_cs2100(client i2c_master_if i2c){
    #define CS2100_DEVICE_CONFIG_1      0x03
    #define CS2100_GLOBAL_CONFIG        0x05
    #define CS2100_FUNC_CONFIG_1        0x16
    #define CS2100_FUNC_CONFIG_2        0x17
    i2c.write_reg(0x9c>>1, CS2100_DEVICE_CONFIG_1, 0);
    i2c.write_reg(0x9c>>1, CS2100_GLOBAL_CONFIG, 0);
    i2c.write_reg(0x9c>>1, CS2100_FUNC_CONFIG_1, 0);
    i2c.write_reg(0x9c>>1, CS2100_FUNC_CONFIG_2, 0);
}

#define MASTER_TO_PDM_CLOCK_DIVIDER 4
#define MASTER_CLOCK_FREQUENCY 24576000
#define PDM_CLOCK_FREQUENCY (MASTER_CLOCK_FREQUENCY/(2*MASTER_TO_PDM_CLOCK_DIVIDER))
#define OUTPUT_SAMPLE_RATE (PDM_CLOCK_FREQUENCY/(32*DECIMATION_FACTOR))

unsafe {
[[distributable]]
void i2s_handler(server i2s_callback_if i2s,
                 client i2c_master_if i2c, 
                 client interface bufget_i filler
                 ) {
  multichannel_audio_block_s * unsafe buffer = 0; // invalid
  unsigned sample_idx=0;

  p_rst_shared <: 0xF;

  init_cs2100(i2c);
  i2c_regop_res_t res;
  int i = 0x4A;
  uint8_t data = i2c.read_reg(i, 1, res);

  data = i2c.read_reg(i, 0x02, res);
  data |= 1;
  res = i2c.write_reg(i, 0x02, data); // Power down

  // Setting MCLKDIV2 high if using 24.576MHz.
  data = i2c.read_reg(i, 0x03, res);
  data |= 1;
  res = i2c.write_reg(i, 0x03, data);

  data = 0b01110000;
  res = i2c.write_reg(i, 0x10, data);

  data = i2c.read_reg(i, 0x02, res);
  data &= ~1;
  res = i2c.write_reg(i, 0x02, data); // Power up

  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_LEFT_JUSTIFIED;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/OUTPUT_SAMPLE_RATE)/64;
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;

    case i2s.receive(size_t index, int32_t sample):
      break;

    case i2s.send(size_t index) -> int32_t sample:
      if(buffer) {
         sample = buffer->data[index][sample_idx];
         //printf("I2S send sample %d on channel %d\n",sample_idx,index);
      } else { // buffer invalid
         sample = 0;
      }
      //xscope_int(index, sample);
      if(index == 1) {
        sample_idx++;
      }
      if(sample_idx>=FFT_N/2) {
        // end of buffer reached.
        sample_idx = 0;
        filler.get_next_buf(buffer);
        //printf("I2S got next buffer at 0x%x\n", buffer);
      }
      break;
    }
  }
}
}


int main(){

    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output[2];

    i2s_callback_if i_i2s;
    i2c_master_if i_i2c[1];
    streaming chan c_audio;

    interface bufget_i bufget;

    par {
      on tile[1]: {
        configure_clock_src(mclk, p_mclk_in1);
        start_clock(mclk);
        i2s_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, bclk, mclk);
      }

      on tile[1]:  [[distribute]]i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
      on tile[1]:  [[distribute]]i2s_handler(i_i2s, i_i2c[0], bufget);
      on tile[1]:  output_audio_dbuf_handler(bufget, triple_buffer, c_audio);
      on tile[0]: {
        configure_clock_src_divide(pdmclk, p_mclk, 4);
        configure_port_clock_output(p_pdm_clk, pdmclk);
        configure_in_port(p_pdm_mics, pdmclk);
        start_clock(pdmclk);
      
        par{
            mic_array_pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
            mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
            mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
            freq_domain_example(c_ds_output, c_audio);
            //par(int i=0;i<4;i++)while(1);
        }
      }
    }
    return 0;
}

