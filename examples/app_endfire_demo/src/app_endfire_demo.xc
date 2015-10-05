#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>

#include "debug_print.h"
#include "xassert.h"

#include "mic_array.h"
#include "mic_array_board_support.h"

#include "i2c.h"
#include "i2s.h"
#include "sine.h"

on tile[0]:p_leds leds = DEFAULT_INIT;
on tile[0]:in port p_buttons =  XS1_PORT_4A;

on tile[0]: in port p_pdm_clk             = XS1_PORT_1E;
on tile[0]: in port p_pdm_mics            = XS1_PORT_8B;
on tile[0]: in port p_mclk                = XS1_PORT_1F;
on tile[0]: clock mclk0                    = XS1_CLKBLK_1;
on tile[0]: clock pdmclk                  = XS1_CLKBLK_2;



out buffered port:32 p_i2s_dout[1]  = on tile[1]: {XS1_PORT_1P};
in port p_mclk_in1                  = on tile[1]: XS1_PORT_1O;
out buffered port:32 p_bclk         = on tile[1]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[1]: XS1_PORT_1N;
out port p_pll_sync                 = on tile[1]: XS1_PORT_4D;
port p_i2c                          = on tile[1]: XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA
port p_rst_shared                   = on tile[1]: XS1_PORT_4F; // Bit 0: DAC_RST_N, Bit 1: ETH_RST_N
clock mclk                          = on tile[1]: XS1_CLKBLK_3;
clock bclk                          = on tile[1]: XS1_CLKBLK_4;

static void set_dir(client interface led_button_if lb, unsigned dir){

    for(unsigned i=0;i<13;i++)
        lb.set_led_brightness(i, 0);
    switch(dir){
    case 0:{
        lb.set_led_brightness(0, 255);
        lb.set_led_brightness(1, 255);
        break;
    }
    case 1:{
        lb.set_led_brightness(2, 255);
        lb.set_led_brightness(3, 255);
        break;
    }
    case 2:{
        lb.set_led_brightness(4, 255);
        lb.set_led_brightness(5, 255);
        break;
    }
    case 3:{
        lb.set_led_brightness(6, 255);
        lb.set_led_brightness(7, 255);
        break;
    }
    case 4:{
        lb.set_led_brightness(8, 255);
        lb.set_led_brightness(9, 255);
        break;
    }
    case 5:{
        lb.set_led_brightness(10, 255);
        lb.set_led_brightness(11, 255);
        break;
    }
    }
}

void lores_DAS_fixed(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
        client interface led_button_if lb, chanend c_audio){

    unsigned buffer = 1;     //buffer index
    frame_audio audio[2];    //double buffered
    memset(audio, sizeof(frame_audio), 0);

#define MAX_DELAY 128

    unsigned delay = 6;
    int delay_buffer[MAX_DELAY][7];
    memset(delay_buffer, sizeof(int)*8*8, 0);
    unsigned delay_head = 0;
    unsigned dir = 0;
    set_dir(lb, dir);

    unsafe{
        c_ds_output_0 <: (frame_audio * unsafe)audio[0].data[0];
        c_ds_output_1 <: (frame_audio * unsafe)audio[0].data[4];

        while(1){

            schkct(c_ds_output_0, 8);
            schkct(c_ds_output_1, 8);

            c_ds_output_0 <: (frame_audio * unsafe)audio[buffer].data[0];
            c_ds_output_1 <: (frame_audio * unsafe)audio[buffer].data[4];

            buffer = 1 - buffer;

            //copy the current sample to the delay buffer
            for(unsigned i=0;i<7;i++)
                delay_buffer[delay_head][i] = audio[buffer].data[i][0];

            //light the LED for the current direction

            int t;

            select {
                case lb.button_event():{
                    unsigned button;
                    e_button_state pressed;
                    lb.get_button_event(button, pressed);
                    if(pressed == BUTTON_PRESSED){
                        switch(button){
                        case 0:{
                            dir--;
                            if(dir == -1)
                                dir = 5;
                            break;
                        }
                        case 1:{
                            if(delay +1 < MAX_DELAY){
                                delay++;
                                printf("n: %d\n", delay);
                            }
                            break;
                        }
                        case 2:{
                            if(delay > 5){
                                delay--;
                                printf("n: %d\n", delay);
                            }
                            break;
                        }
                        case 3:{
                            dir++;
                            if(dir == 6)
                                dir = 0;
                            break;
                        }
                        }
                        set_dir(lb, dir);
                    }
                    break;
                }
                default:break;
            }

            int output = - 2*delay_buffer[(delay_head-delay)%MAX_DELAY][0];
            switch(dir){
            case 0:
                output = delay_buffer[delay_head][1] + delay_buffer[(delay_head-2*delay)%MAX_DELAY][4];
                break;
            case 1:
                output = delay_buffer[delay_head][2] + delay_buffer[(delay_head-delay)%MAX_DELAY][5];
                break;
            case 2:
                output = delay_buffer[delay_head][3] + delay_buffer[(delay_head-delay)%MAX_DELAY][6];
                break;
            case 3:
                output = delay_buffer[delay_head][4] + delay_buffer[(delay_head-delay)%MAX_DELAY][1];
                break;
            case 4:
                output = delay_buffer[delay_head][5] + delay_buffer[(delay_head-delay)%MAX_DELAY][2];
                break;
            case 5:
                output = delay_buffer[delay_head][6] + delay_buffer[(delay_head-delay)%MAX_DELAY][3];
                break;
            }
            c_audio <: output<<2;
            c_audio <: output<<2;
        }
    }
}

#define OUTPUT_SAMPLE_RATE 48000
#define MASTER_CLOCK_FREQUENCY 24576000

[[distributable]]
void i2s_handler(server i2s_callback_if i2s,
                 client i2c_master_if i2c, chanend c_audio)
{

  p_rst_shared <: 0xF;

  i2c_regop_res_t res;
  int i = 0x4A;
  uint8_t data = i2c.read_reg(i, 1, res);
  debug_printf("I2C ID: %x, res: %d\n", data, res);

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
      break;
    }
  }
};

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
            streaming chan c_ds_output_0, c_ds_output_1;

            interface led_button_if lb;

            configure_clock_src(mclk0, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk0);
            start_clock(pdmclk);
            decimator_config dc = {0, 1, 0, 0};
            par{
                button_and_led_server(lb, leds, p_buttons);
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_0, c_ds_output_0, dc);
                decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_1, c_ds_output_1, dc);
                lores_DAS_fixed(c_ds_output_0, c_ds_output_1, lb,c_audio);
            }
        }
    }
    return 0;
}
