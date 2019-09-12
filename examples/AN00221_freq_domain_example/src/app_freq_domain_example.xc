// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved

#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include "i2c.h"
#include "i2s.h"
#include "mic_array.h"
#include "mic_array_board_support.h"
#include "dsp.h"

#define DECIMATION_FACTOR   2   //Corresponds to a 48kHz output sample rate
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define NUM_FRAME_BUFFERS   3   //Triple buffer needed for overlapping frames
#define NUM_OUTPUT_CHANNELS 2

//Ports for the PDM microphones
on tile[0]: out port p_pdm_clk              = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

//Ports for the DAC and clocking
out buffered port:32 p_i2s_dout[1]  = on tile[1]: {XS1_PORT_1P};
in port p_mclk_in1                  = on tile[1]: XS1_PORT_1O;
out buffered port:32 p_bclk         = on tile[1]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[1]: XS1_PORT_1N;
port p_i2c                          = on tile[1]: XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA
port p_rst_shared                   = on tile[1]: XS1_PORT_4F; // Bit 0: DAC_RST_N, Bit 1: ETH_RST_N
clock mclk                          = on tile[1]: XS1_CLKBLK_3;
clock bclk                          = on tile[1]: XS1_CLKBLK_4;

//The number of bins in the FFT (defined in this case by
// MIC_ARRAY_MAX_FRAME_SIZE_LOG2 given in mic_array_conf.h)
#define FFT_N (1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2)

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

int your_favourite_window_function(unsigned i, unsigned window_length){
    //Hanning function takes 10k memory which blows up the memory with FFT_N 4k
    //TODO: Optimise using dsp_math_sqrt and dsp_math_cos.
    //Hanning window
    return((int)((double)INT_MAX*sqrt(0.5*(1.0 - cos(2.0 * 3.14159265359*(double)i / (double)(window_length-2))))));

    //Rectangular
    //return INT_MAX;
}

// make global to enforce 64 bit alignment
multichannel_audio_block_s triple_buffer[3];

//Data memory for the lib_mic_array decimation FIRs
int data[8][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

void apply_window_function(dsp_complex_t p[], int window[], unsigned N) {
    //apply the window function
    for(unsigned i=0;i<N/2;i++){
       uint64_t t = (uint64_t)window[i] * (uint64_t)p[i].re;
       p[i].re = (t>>31);
       t = (uint64_t)window[i] * (uint64_t)p[i].im;
       p[i].im = (t>>31);
    }
    for(unsigned i=N/2;i<N;i++){
       uint64_t t = (uint64_t)window[N-1-i] * (uint64_t)p[i].re;
       p[i].re = (t>>31);
       t = (uint64_t)window[N-1-i] * (uint64_t)p[i].im;
       p[i].im = (t>>31);
    }
}


void freq_domain_example(streaming chanend c_ds_output[2], streaming chanend c_audio){

    unsigned buffer ;
    mic_array_frame_fft_preprocessed comp[NUM_FRAME_BUFFERS];

    memset(data, 0, sizeof(int)*8*THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR);

    int window[FFT_N/2];
    for(unsigned i=0;i<FFT_N/2;i++)
         window[i] = your_favourite_window_function(i, FFT_N);

    unsafe {
        mic_array_decimator_conf_common_t dcc = {
                MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
                1,
                1, // bit reversed indexing for data in the buffer. Can be processed directly by dsp_fft_forward
                window,
                DECIMATION_FACTOR,
                g_third_stage_div_2_fir,
                0,
                FIR_COMPENSATOR_DIV_2,
                DECIMATOR_HALF_FRAME_OVERLAP,
                NUM_FRAME_BUFFERS
        };

        mic_array_decimator_config_t dc[2] = {
                {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0},
                {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0}
        };

        mic_array_decimator_configure(c_ds_output, 2, dc);

        mic_array_init_frequency_domain_frame(c_ds_output, 2, buffer, comp, dc);

        while(1){
           dsp_complex_t p[FFT_N]; // use as tmp buffer as well as output buffer

           //Receive the preprocessed frames ready for the FFT
           mic_array_frame_fft_preprocessed * current = mic_array_get_next_frequency_domain_frame(c_ds_output, 2, buffer, comp, dc);

           for(unsigned i=0;i<MIC_ARRAY_NUM_FREQ_CHANNELS;i++){
#if MIC_ARRAY_WORD_LENGTH_SHORT
               // convert current->data[i] into p
               dsp_fft_short_to_long(p, (dsp_complex_short_t*)current->data[i], FFT_N); 

               //Apply one FFT to two channels at a time
               dsp_fft_forward(p, FFT_N, dsp_sine_512);
               //Reconstruct the two independent frequency domain representations
               dsp_fft_split_spectrum(p, FFT_N);
               // convert p back into current->data[i]
               dsp_fft_long_to_short((dsp_complex_short_t*)current->data[i], p, FFT_N); 
#else
               //Apply one FFT to two channels at a time
               dsp_fft_forward((dsp_complex_t*)current->data[i], FFT_N, dsp_sine_512);

               //Reconstruct the two independent frequency domain representations
               dsp_fft_split_spectrum((dsp_complex_t*)current->data[i], FFT_N);
#endif
           }
           mic_array_frame_frequency_domain * frequency = (mic_array_frame_frequency_domain*)current;


           /*
            *Work in the frequency domain here:
           */ 

           //For example, low pass filter of channel 0
           //cutoff Frequency = (Fs/FFT_N * cutoff_index)
           //With cutoff_index = FFT_N/M:
           //cut off Frequency = Fs/M
           //e.g. Fs = 16kHz, M=4: cutoff frequency = 4kHz
           for(unsigned i = FFT_N/4; i < FFT_N/2; i++){
               frequency->data[0][i].re = 0;
               frequency->data[0][i].im = 0;
           }
           //Don't forget the nyquest rate
           frequency->data[0][0].im = 0;


           //For example, high pass filter of channel 1
           //Same cutoff frequency as above
           frequency->data[1][0].re = 0;
           for(unsigned i = 1; i < FFT_N/4; i++){
               frequency->data[1][i].re = 0;
               frequency->data[1][i].im = 0;
           }

           //Now to get channel 0 and channel 1 back to the time domain=
#if MIC_ARRAY_WORD_LENGTH_SHORT
           // Note! frequency is an alias of current. current->data[0] has frequency->data[0] and frequency->data[1]
           // So we can convert directly into p
           dsp_fft_short_to_long(p, (dsp_complex_short_t*)current->data[0], FFT_N); // convert into tmp buffer
#else
           memcpy(&p[0],       frequency->data[0], sizeof(dsp_complex_t)*FFT_N/2);
           memcpy(&p[FFT_N/2], frequency->data[1], sizeof(dsp_complex_t)*FFT_N/2);
#endif

           dsp_fft_merge_spectra(p, FFT_N);
           dsp_fft_bit_reverse(p, FFT_N);
           dsp_fft_inverse(p, FFT_N, dsp_sine_512);
           //Now the p array is a time domain representation of the selected channel.
           //   -The imaginary component will be the channel 1 time domain representation.
           //   -The real component will be the channel 0 time domain representation.

           apply_window_function(p, window, FFT_N);

           for(unsigned i=0; i<FFT_N ; i++) {
             c_audio <: p[i].re; // output channel 0
             c_audio <: p[i].im; // output channel 1
           }
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
        break;
    }
  }
}
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

  mabs_init_pll(i2c, ETH_MIC_ARRAY);

  i2c_regop_res_t res;
  int i = 0x4A;

  uint8_t data = 1;
  res = i2c.write_reg(i, 0x02, data); // Power down

  data = 0x08;
  res = i2c.write_reg(i, 0x04, data); // Slave, I2S mode, up to 24-bit

  data = 0;
  res = i2c.write_reg(i, 0x03, data); // Disable Auto mode and MCLKDIV2

  data = 0x00;
  res = i2c.write_reg(i, 0x09, data); // Disable DSP

  data = 0;
  res = i2c.write_reg(i, 0x02, data); // Power up

  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
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
            mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
            mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
            freq_domain_example(c_ds_output, c_audio);
            //par(int i=0;i<4;i++)while(1);
        }
      }
    }
    return 0;
}

