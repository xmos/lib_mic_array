// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>
#include <math.h>
#include <limits.h>
#include <print.h>

#include "mic_array.h"
#include "mic_array_board_support.h"

#include "lib_dsp.h"

#include "i2c.h"
#include "i2s.h"

#include "beamforming.h"

#define DF 2    //Decimation Factor

on tile[0]:p_leds leds = DEFAULT_INIT;
on tile[0]:in port p_buttons =  XS1_PORT_4A;

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

out buffered port:32 p_i2s_dout[1]  = on tile[1]: {XS1_PORT_1P};
in port p_mclk_in1                  = on tile[1]: XS1_PORT_1O;
out buffered port:32 p_bclk         = on tile[1]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[1]: XS1_PORT_1N;
out port p_pll_sync                 = on tile[1]: XS1_PORT_4D;
port p_i2c                          = on tile[1]: XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA
port p_rst_shared                   = on tile[1]: XS1_PORT_4F; // Bit 0: DAC_RST_N, Bit 1: ETH_RST_N
clock mclk                          = on tile[1]: XS1_CLKBLK_3;
clock bclk                          = on tile[1]: XS1_CLKBLK_4;

#define FFT_N (1<<MAX_FRAME_SIZE_LOG2)

void output_frame(chanend c_audio, int proc_buffer[4][FFT_N/2], lib_dsp_fft_complex_t p[FFT_N],
        unsigned &head, int * window){

    lib_dsp_fft_rebuild_one_real_input(p, FFT_N);
    lib_dsp_fft_bit_reverse(p, FFT_N);
    lib_dsp_fft_inverse_complex(p, FFT_N, lib_dsp_sine_512);

    //apply the window function
    for(unsigned i=0;i<FFT_N/2;i++){
       long long t = (long long)window[i] * (long long)p[i].re;
       p[i].re = (t>>31);
    }
    for(unsigned i=FFT_N/2;i<FFT_N;i++){
       long long t = (long long)window[FFT_N-1-i] * (long long)p[i].re;
       p[i].re = (t>>31);
    }

    for(unsigned i=0;i<FFT_N/2;i++){
        proc_buffer[head][i] += p[i].re;
        proc_buffer[(head+1)%4][i] = p[i+FFT_N/2].re;
    }

    unsafe {
        c_audio <: (int * unsafe)(proc_buffer[head]);
    }
    head++;
    if(head == 4)
        head = 0;
}

{int, int} foo(int x, int y, unsigned old_h, unsigned new_h){
    if(old_h){
        x = (long long)x * (long long)new_h / (long long)old_h;
        y = (long long)y * (long long)new_h / (long long)old_h;
    }
   return {x, y};
}

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};

typedef struct {
    unsigned long long energy_lpf[MIC_ARRAY_NUM_MICS];
    unsigned hang_over;
} vad_state;

typedef struct {
    int signal_gain;
    int noise_gain;
} agc_state;

void compute_freq_magnitude_single_channel(frame_frequency * f, unsigned mag[], unsigned ch){
    for(unsigned i=0;i<FFT_N/2;i++){
        int re = f->data[ch][i].re;
        int im = f->data[ch][i].im;
        mag[i] = hypot_i(re, im);
    }
}

void compute_freq_magnitude(frame_frequency * f, unsigned mag[MIC_ARRAY_NUM_MICS][FFT_N/2]){
    for(unsigned ch=0;ch<MIC_ARRAY_NUM_MICS;ch++){
        compute_freq_magnitude_single_channel(f, mag[ch], ch);
    }
}

/*
 * The upper word of lpf[i] will contain mag[i] low pass filtered
 */
void low_pass_filter_u(unsigned long long lpf[], unsigned mag[], unsigned array_length, unsigned shift){
    //need to treat 0(DC) and the final bin seperatly
    for(unsigned i=1;i<array_length;i++){
        unsigned long long h = (unsigned long long)mag[i];
        h <<= (32 - shift);
        lpf[i] = lpf[i] - (lpf[i]>>shift) + h;
    }
}

/*
 * The upper word of lpf[i] will contain mag[i] low pass filtered
 */
void low_pass_filter_s(long long lpf[], int mag[], unsigned array_length, unsigned shift){
    //need to treat 0(DC) and the final bin seperatly
    for(unsigned i=1;i<array_length;i++){
        long long h = mag[i];
        h <<= (31 - shift);
        lpf[i] = lpf[i] - (lpf[i]>>shift) + h;
    }
}


int vad_single_channel(unsigned mag[], unsigned long long lpf[], vad_state &v, unsigned channel){

    unsigned long long energy = 0;
    for(unsigned i=1;i<32;i++){
        energy += ((long long)mag[i]);
    }
    unsigned e = energy/32;
    unsigned shift = 8;
    unsigned long long h = (unsigned long long)energy;
    h <<= (32 - shift);
    v.energy_lpf[channel]  = v.energy_lpf[channel]  - (v.energy_lpf[channel] >> shift) + h;
    unsigned o =v.energy_lpf[channel] >> (32+5);

    int thresh = e>o;
    if(thresh){
        v.hang_over = 20;
        return 1;
    } else {
        if(v.hang_over){
            v.hang_over--;
            return 1;
        } else
            return 0;
    }
}

void vad(unsigned mag[MIC_ARRAY_NUM_MICS][FFT_N/2], unsigned long long lpf[], vad_state &v, int is_voice[MIC_ARRAY_NUM_MICS]){
    for(unsigned i=0;i<MIC_ARRAY_NUM_MICS;i++)
        is_voice[i] = vad_single_channel(mag[i], lpf, v, i);
}

void noise_red(streaming chanend c_ds_output[2],
        client interface led_button_if lb, chanend c_audio){

    unsigned buffer ;     //buffer index
    frame_complex comp[4];
    memset(comp, 0, sizeof(frame_complex)*4);
    lib_dsp_fft_complex_t p[FFT_N];
    int window[FFT_N/2];
    for(unsigned i=0;i<FFT_N/2;i++){
         window[i] = (int)((double)INT_MAX*sqrt(0.5*(1.0 - cos(2.0 * 3.14159265359*(double)i / (double)(FFT_N-2)))));
    }

    unsafe{
        decimator_config_common dcc = {
                MAX_FRAME_SIZE_LOG2,
                1,
                1,
                window,
                DF,
                g_third_stage_div_2_fir,
                0,
                0,
                DECIMATOR_HALF_FRAME_OVERLAP,
                4
        };
        decimator_config dc[2] = {
                {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        decimator_configure(c_ds_output, 2, dc);

        decimator_init_complex_frame(c_ds_output, 2, buffer, comp, dcc);

        int proc_buffer[4][FFT_N/2];

        memset(proc_buffer, 0, sizeof(int)*4*FFT_N/2);

        unsigned head = 0;

        unsigned long long lpf[FFT_N/2] = {0};
        int enabled = 1;

#define FLOOR 3
        vad_state vad;
        memset(&vad, 0, sizeof(vad));
        unsigned shift = 9;
        while(1){
           frame_complex * current = decimator_get_next_complex_frame(c_ds_output, 2, buffer, comp, dcc);


               unsigned c=32;

               for(unsigned i=0;i<FFT_N;i++){
                   int d = current->data[0][i].re;
                   if(d<0) d=-d;
                   unsigned t = clz(d);
                   if(t<c)
                       c=t;
               }

               for(unsigned i=0;i<FFT_N;i++){
                   current->data[0][i].re<<=(c-2);
               }

           for(unsigned i=0;i<4;i++){
               lib_dsp_fft_forward_complex((lib_dsp_fft_complex_t*)current->data[i], FFT_N, lib_dsp_sine_512);
               lib_dsp_fft_reorder_two_real_inputs((lib_dsp_fft_complex_t*)current->data[i], FFT_N);
           }
           frame_frequency * frequency = (frame_frequency *)current;

           unsigned mag[FFT_N/2];

           compute_freq_magnitude_single_channel(frequency, mag, 0);

           int is_voice = vad_single_channel(mag, lpf, vad, 0);

           if(is_voice){
               lb.set_led_brightness(11, 255);
           } else {
               lb.set_led_brightness(11, 0);
           }
           low_pass_filter_u(lpf, mag, FFT_N/2, shift);

           //frequency->data[0][0].re = 0;      //remove dc offset
           //frequency->data[0][0].im = 0;      //remove highest frequency bin, i think??
           if(enabled){
               if(1){
#define PLOT_FREQ 0
#if PLOT_FREQ
                   xscope_int(0, 0);
                   xscope_int(1, 0);
#endif
                   for(unsigned i=1; i<FFT_N/2-2;i++){
                       unsigned current_mag = mag[i];
                       unsigned noise_mag = (lpf[i]>>32);
#if PLOT_FREQ
                       xscope_int(0, noise_mag);
                       xscope_int(1, current_mag);
                       delay_microseconds(5);
#endif
                       if(current_mag > noise_mag*2){
                           unsigned output = current_mag - noise_mag*2;
                           if((current_mag>>FLOOR) < output){   //suppression limiting
                               int re = frequency->data[0][i].re;
                               int im = frequency->data[0][i].im;
                               {re, im} = foo(re, im, current_mag, output);
                               frequency->data[0][i].re = re;
                               frequency->data[0][i].im = im;
                           } else {
                               frequency->data[0][i].re >>= FLOOR;
                               frequency->data[0][i].im >>= FLOOR;
                           }
                       } else {
                           frequency->data[0][i].re >>= (FLOOR);
                           frequency->data[0][i].im >>= (FLOOR);
                       }
                   }
#if PLOT_FREQ
               xscope_int(0, 0);
               xscope_int(1, 0);
#endif
               } else {
#define NOISE_ATTEN 5
                   for(unsigned i=1; i<FFT_N/2-2;i++){
                       frequency->data[0][i].re >>= (NOISE_ATTEN);
                       frequency->data[0][i].im >>= (NOISE_ATTEN);
                   }
               }
           }

           //apply agc(is_voice)
           select {
               case lb.button_event():{
                   unsigned button;
                   e_button_state pressed;
                   lb.get_button_event(button, pressed);
                   if(pressed == BUTTON_PRESSED){
                       if(button == 0){
                           shift++;
                           printf("shift: %d\n", shift);
                       }
                       if(button == 1){
                           shift--;
                           printf("shift: %d\n", shift);

                       }
                       if(button == 2){
                           enabled = 1-enabled;
                           printf("%d\n", enabled);
                       }
                       if(button == 3){
                           _Exit(1);
                       }
                   }
                   break;
               }
               default:break;
           }

           for(unsigned i=0;i<FFT_N/2;i++){
               p[i].re =  frequency->data[0][i].re>>(c-3);
               p[i].im =  frequency->data[0][i].im>>(c-3);
           }

           output_frame(c_audio, proc_buffer, p, head, window);
        }
    }
}

void decouple(chanend c_in, chanend c_out){
    unsafe {
        int * unsafe p_head;
        int * unsafe p_tail = 0;
        c_in :> p_head;
        unsigned head = 0;
        while(1){
           select {
               case (p_tail == 0) => c_in :> p_tail:{
                   break;
               }
               default:break;
           }
           if(p_head) {

               c_out <: p_head[head];
               c_out <: p_head[head];

              //xscope_int(0, p_head[head]);

               head++;
               if(head == FFT_N/2){
                   head = 0;
                   p_head = p_tail;
                   p_tail = 0;
               }
           } else {
               c_out <: 0;
               c_out <: 0;
               head = 0;
               p_head = p_tail;
               p_tail = 0;
           }
        }
    }
}


#define OUTPUT_SAMPLE_RATE (96000/DF)
#define MASTER_CLOCK_FREQUENCY 24576000
[[distributable]]
void i2s_handler(server i2s_callback_if i2s,
                 client i2c_master_if i2c, chanend c_audio)
{

  p_rst_shared <: 0xF;

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

#define CS2100_I2C_DEVICE_ADDR      (0x9c>>1)
  res = i2c.write_reg(CS2100_I2C_DEVICE_ADDR, 0x3, 0); // Reset the PLL to use the aux out

  while (1) {
    select {

    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      /* Configure the I2S bus */
      i2s_config.mode = I2S_MODE_LEFT_JUSTIFIED;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/OUTPUT_SAMPLE_RATE)/64;

      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      // This application never restarts the I2S bus
      restart = I2S_NO_RESTART;
      break;

    case i2s.receive(size_t index, int32_t sample):
      break;

    case i2s.send(size_t index) -> int32_t sample:
      c_audio:> sample;
      sample <<=3;
      break;
    }
  }
}

int main(){

    i2s_callback_if i_i2s;
    i2c_master_if i_i2c[1];
    chan c_audio, c_decoupled;
    par{

        on tile[1]: {
          configure_clock_src(mclk, p_mclk_in1);
          start_clock(mclk);
          i2s_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, bclk, mclk);
        }

        on tile[1]:  [[distribute]]i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
        on tile[1]:  [[distribute]]i2s_handler(i_i2s, i_i2c[0], c_decoupled);

        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output[2];

            interface led_button_if lb[1];

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            par{
                decouple(c_audio, c_decoupled);
                button_and_led_server(lb, 1, leds, p_buttons);
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
                decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
                noise_red(c_ds_output, lb[0], c_audio);
            }
        }
    }
    return 0;
}

