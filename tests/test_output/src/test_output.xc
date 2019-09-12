// Copyright (c) 2015-2019, XMOS Ltd, All rights reserved
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
#include "mic_array.h"
#include "mic_array_board_support.h"

#include "i2c.h"
#include "i2s.h"

#define DF 2    //Decimation Factor

on tile[0]:mabs_led_ports_t leds = MIC_BOARD_SUPPORT_LED_PORTS;
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

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};

void test_output(streaming chanend c_ds_output[2],
        client interface mabs_led_button_if lb, chanend c_audio){

    mic_array_frame_time_domain audio[2];

    printf("Output test started\n");
    unsafe{
        unsigned buffer;     //buffer index
        memset(audio, sizeof(mic_array_frame_time_domain), 0);

        unsigned gain = 8;

        mic_array_decimator_conf_common_t dcc = {MIC_ARRAY_MAX_FRAME_SIZE_LOG2, 1, 0, 0, DF,
                g_third_stage_div_2_fir, 0, FIR_COMPENSATOR_DIV_2,
                DECIMATOR_NO_FRAME_OVERLAP, 2};
        mic_array_decimator_config_t dc[2] = {
                    {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0},
                    {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0}
            };
        mic_array_decimator_configure(c_ds_output, 2, dc);

        mic_array_init_time_domain_frame(c_ds_output, 2, buffer, audio, dc);

        unsigned c=0;
        timer t;
        unsigned now, then;
        mic_array_get_next_time_domain_frame(c_ds_output, 2, buffer, audio, dc);
        t :> then;
#define SAMPLES 0x3fff
        for(unsigned i=0;i<SAMPLES;i++)
            mic_array_get_next_time_domain_frame(c_ds_output, 2, buffer, audio, dc);
        t:> now;
        printf("Sample rate of the microphone output: %f\n",((float)SAMPLES*100000000.0)/(float)(now- then));

        while(1){
            mic_array_frame_time_domain *  current = mic_array_get_next_time_domain_frame(c_ds_output, 2, buffer, audio, dc);
            select {
                case lb.button_event():{
                    unsigned button;
                    mabs_button_state_t pressed;
                    lb.get_button_event(button, pressed);
                    if(pressed == BUTTON_PRESSED){
                        switch(button){
                        case 0:
                        case 1:{
                            gain++;
                            printf("gain: %d\n", gain);
                            break;
                        }
                        case 2:
                        case 3:{
                            gain--;
                            printf("gain: %d\n", gain);
                            break;
                        }
                        }
                    }
                    break;
                }
                default:break;
            }

            for(int j=0;j<1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2;j++){
                int output = current->data[0][j];
                output *= gain;
                c_audio <: output;
                c_audio <: output;

                for(unsigned i=0;i<8;i++){
                    xscope_int(i, current->data[i][j]);
                }

            }
        }
    }
}

#define OUTPUT_SAMPLE_RATE (96000/DF)
#define MASTER_CLOCK_FREQUENCY 24576000
[[distributable]]
void i2s_handler(server i2s_callback_if i2s,
                 client i2c_master_if i2c, chanend c_audio){
  p_rst_shared <: 0xF;

  mabs_init_pll(i2c, ETH_MIC_ARRAY);

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

  timer t;
  unsigned now, then;
  t:> then;

  unsigned count = 0;
  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      /* Configure the I2S bus */
      i2s_config.mode = I2S_MODE_LEFT_JUSTIFIED;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/OUTPUT_SAMPLE_RATE)/64;
      break;
    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;
    case i2s.receive(size_t index, int32_t sample):
      break;
    case i2s.send(size_t index) -> int32_t sample:

      if(count < SAMPLES){
          count++;
          if(count == SAMPLES){
              t:> now;
              printf("Sample rate of the i2s output: %f\n",((float)SAMPLES*100000000.0/2.0)/(float)(now- then));
          }
      } else {
            c_audio:> sample;
      }
      break;
    }
  }
}


void test_pdm_clock(){
    unsigned time, now, then;
    timer t;
    t :> time;
    t:> then;
    int testing_mclk = 1;
    p_pdm_mics:> int;
    #define CLOCK_COUNT 1000000
    while(testing_mclk){
        select {
            case t when timerafter(time + 100000000):> time:{
                printf("Time out on PDM clock\n");
                testing_mclk = 0;
                break;
            }
            case p_pdm_mics:> int:{
                testing_mclk++;
                t :> time;
                if(testing_mclk == CLOCK_COUNT){
                    printf("PDM clock present: ");
                    t:> now;
                    unsigned elapsed =  (now - then);
                    float t = (CLOCK_COUNT)/ (((float)elapsed*2)*10.0) * 1000.0;
                    printf("%fMHz\n", t);
                    testing_mclk = 0;
                }
                break;
            }
        }
    }
}

void sine_gen(streaming chanend c_sine){
#define SINE_FREQ 1000
#define LUT_SIZE (OUTPUT_SAMPLE_RATE / SINE_FREQ)

    int sine[LUT_SIZE];
    for(unsigned i=0;i<LUT_SIZE;i++)
        sine[i] = (int)((float)INT_MAX * sin(2*3.141592654*(float)i/(float)LUT_SIZE));

    while(1){
        for(unsigned i=0;i<LUT_SIZE;i++) mic_array_send_sample(c_sine, sine[i]);
    }
}

int main(){

    i2s_callback_if i_i2s;
    i2c_master_if i_i2c[1];
    chan c_audio;
    par{
        on tile[1]: {
          configure_clock_src(mclk, p_mclk_in1);
          start_clock(mclk);
          i2s_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, bclk, mclk);
        }

        on tile[1]:  [[distribute]]i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
        on tile[1]:  [[distribute]]i2s_handler(i_i2s, i_i2c[0], c_audio);

        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output[2];

            interface mabs_led_button_if lb[1];

            test_pdm_clock();

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_internal_audio;

            par{
                mabs_button_and_led_server(lb, 1, leds, p_buttons);
                mic_array_pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
                {
                    mic_array_internal_audio_channels internal_channels[4];
                    mic_array_init_far_end_channels(internal_channels, null, null, null, c_internal_audio);
                    mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1], internal_channels);
                }
                test_output(c_ds_output, lb[0], c_audio);
                sine_gen(c_internal_audio);
            }
        }
    }
    return 0;
}
