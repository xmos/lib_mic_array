// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include <string.h>
#include <xclib.h>
#include <stdio.h>

#include "mic_array.h"
#include "mic_array_board_support.h"
#include "debug_print.h"

#include "i2c.h"
#include "i2s.h"

#include "double_buffer.h"
#include "mic_array_conf.h"

//If the decimation factor is changed the the coefs array of decimator_config must also be changed.
#define DECIMATION_FACTOR   6   //Corresponds to a 16kHz output sample rate
#define FIR_COMPENSATOR FIR_COMPENSATOR_DIV_6
#define THIRD_STAGE_DIV_FIR g_third_stage_div_6_fir
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define FRAME_BUFFER_COUNT  2   //The minimum of 2 will suffice for this example
#define I2S_MODE I2S_MODE_LEFT_JUSTIFIED

on tile[0]:mabs_led_ports_t leds = MIC_BOARD_SUPPORT_LED_PORTS;
on tile[0]:in port p_buttons =  MIC_BOARD_SUPPORT_BUTTON_PORTS;

on tile[0]: out port p_pdm_clk              = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

out buffered port:32 p_i2s_dout[1]  = on tile[1]: {XS1_PORT_1P};
in port p_mclk_in1                  = on tile[1]: XS1_PORT_1O;
out port p_bclk         = on tile[1]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[1]: XS1_PORT_1N;
port p_i2c                          = on tile[1]: XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA
port p_rst_shared                   = on tile[1]: XS1_PORT_4F; // Bit 0: DAC_RST_N, Bit 1: ETH_RST_N
clock mclk                          = on tile[1]: XS1_CLKBLK_3;
clock bclk                          = on tile[1]: XS1_CLKBLK_4;

// Based on the spreadsheet mic_array_das_beamformer_calcs.xls,
// which can be found in the root directory of this app
static const one_meter_thirty_degrees[6] = {0, 23, 66, 87, 66, 23};

static void set_dir(client interface mabs_led_button_if lb,
                    unsigned dir, unsigned delay[]) {

    for(unsigned i=0;i<MIC_BOARD_SUPPORT_LED_COUNT;i++)
        lb.set_led_brightness(i, 0);
    delay[0] = 43;
    for(unsigned i=0;i<6;i++)
        delay[i+1] = one_meter_thirty_degrees[(i - dir + 3 +6)%6];

    switch(dir){
    case 0:
        lb.set_led_brightness(0, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        lb.set_led_brightness(1, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        break;
    case 1:
        lb.set_led_brightness(2, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        lb.set_led_brightness(3, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        break;
    case 2:
        lb.set_led_brightness(4, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        lb.set_led_brightness(5, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        break;
    case 3:
        lb.set_led_brightness(6, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        lb.set_led_brightness(7, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        break;
    case 4:
        lb.set_led_brightness(8, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        lb.set_led_brightness(9, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        break;
    case 5:
        lb.set_led_brightness(10, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        lb.set_led_brightness(11, MIC_BOARD_SUPPORT_MAX_LED_BRIGHTNESS);
        break;
    }
}

int data[8][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

void hires_DAS_fixed(streaming chanend c_ds_output[2],
        streaming chanend c_cmd,
        client interface mabs_led_button_if lb, chanend c_audio) {
    unsafe {
        mic_array_frame_time_domain audio[FRAME_BUFFER_COUNT];
        unsigned buffer;
        memset(data, 0, 8*THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR*sizeof(int));

        unsigned gain = 8;
        unsigned delay[7];
        unsigned dir = 0;
        set_dir(lb, dir, delay);

        mic_array_decimator_conf_common_t dcc = {0, 1, 0, 0, DECIMATION_FACTOR,
               THIRD_STAGE_DIV_FIR, 0, FIR_COMPENSATOR,
               DECIMATOR_NO_FRAME_OVERLAP, FRAME_BUFFER_COUNT};
        mic_array_decimator_config_t dc[2] = {
          {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
          {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        mic_array_decimator_configure(c_ds_output, DECIMATOR_COUNT, dc);

        mic_array_init_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        while(1) {

            mic_array_frame_time_domain *  current =
                               mic_array_get_next_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

            // light the LED for the current directionction

            int t;
            select {
                case lb.button_event(): {
                    unsigned button;
                    mabs_button_state_t pressed;
                    lb.get_button_event(button, pressed);
                    if (pressed == BUTTON_PRESSED) {
                        switch(button) {
                        case 0:
                            dir--;
                            if(dir == -1)
                                dir = 5;
                            set_dir(lb, dir, delay);

                            debug_printf("dir %d\n", dir+1);
                            for(unsigned i=0;i<7;i++)
                                debug_printf("delay[%d] = %d\n", i, delay[i]);
                            debug_printf("\n");

                            mic_array_hires_delay_set_taps(c_cmd, delay, 7);
                            break;

                        case 1:
                            if (gain > 0)
                                gain--;
                            debug_printf("gain: %d\n", gain);
                            break;

                        case 2:
                            gain++;
                            debug_printf("gain: %d\n", gain);
                            break;

                        case 3:
                            dir++;
                            if(dir == 6)
                                dir = 0;
                            set_dir(lb, dir, delay);

                            debug_printf("dir %d\n", dir+1);
                            for(unsigned i=0;i<7;i++)
                                debug_printf("delay[%d] = %d\n", i, delay[i]);
                            debug_printf("\n");

                            mic_array_hires_delay_set_taps(c_cmd, delay, 7);
                            break;
                        }
                    }
                    break;
                }
                default:break;
            }
            int output = 0;
            for(unsigned i=0;i<7;i++)
                output += (current->data[i][0]>>3);
            output *= gain;

            // Update the center LED with a volume indicator
            unsigned value = output >> 20;
            unsigned magnitude = (value * value) >> 8;
            lb.set_led_brightness(12, magnitude);

            c_audio <: output;
            c_audio <: output;
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

interface dbuf_store_if {
  void store(BUFFER_TYPE val);
};

interface dbuf_ptr_if {
  void sync(BUFFER_TYPE * unsafe &buf_ptr);
};

int is_power_of_two(unsigned int x)
{
 unsigned int pot = 1;

 while (pot < x && pot < 2147483648)
   pot *= 2;
 return (x == pot);
}

[[distributable]]
void i2s_handler(server i2s_frame_callback_if i2s,
                 client i2c_master_if i2c, chanend c_audio,
                 client interface dbuf_store_if i_dbuf) {
  p_rst_shared <: 0xF;

  init_cs2100(i2c);
  i2c_regop_res_t res;
  int i = 0x4A;
  uint8_t data = i2c.read_reg(i, 1, res);

#if I2S_MODE==I2S_MODE_I2S // default is I2S_MODE_LEFT_JUSTIFIED
  data = i2c.read_reg(i, 0x04, res);
  data &= ~0b00111000; // set DAC_DIF[2:0] to 0
  data |= 0b00001000;  // set mode I2S, up to 24-bit data
  res = i2c.write_reg(i, 0x04, data); // I2S mode
#endif

  data = i2c.read_reg(i, 0x02, res);
  data |= 1;
  res = i2c.write_reg(i, 0x02, data); // Power down

  int mclk_lrclk_ratio = MASTER_CLOCK_FREQUENCY/OUTPUT_SAMPLE_RATE;
  data = i2c.read_reg(i, 0x03, res);
  // See Table 3. MCLK/LRCK Ratios in CS43L21_F1.pdf
  data |= 1;   // Setting MCLKDIV2 high for both cases
  if(mclk_lrclk_ratio==1536) { // 16kHz with 24.576 MHz MLCK.
      // Change SPEED to HSM
      data &= ~0b01100000; // set SPEED bits to 0
      data |= 0b01000000;  // set to HSM
  }
  res = i2c.write_reg(i, 0x03, data);

  data = 0b01110000;
  res = i2c.write_reg(i, 0x10, data);

  data = i2c.read_reg(i, 0x02, res);
  data &= ~1;
  res = i2c.write_reg(i, 0x02, data); // Power up


  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE;
      i2s_config.mclk_bclk_ratio = mclk_lrclk_ratio/64;
      break;
    
    case i2s.receive(size_t num_chan_in, int32_t sample[num_chan_in]):
      // there is no I2S input
      break;

    case i2s.send(size_t num_chan_out, int32_t sample[num_chan_out]):
      for (size_t i=0; i<num_chan_out; i++){
        int32_t s;
        c_audio :> s;
        #if MIC_ARRAY_WORD_LENGTH_SHORT
          sample[i] = s << 16;
        #else 
          sample[i] = s;
        #endif
        if(i == 0) i_dbuf.store(sample[i]); // store samples of channel 0 into double buffer
      }
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;
    }
  }
}

unsafe {
[[distributable]] //distribute server task across client logical cores
void double_buffer(server interface dbuf_store_if i_dbuf, client interface dbuf_ptr_if i_dbuf_swap){

    BUFFER_TYPE dbuf[2][BUF_SIZE];    //The global value that both tasks can access

    int input_buf=0;
    int input_idx=0;

    BUFFER_TYPE * unsafe output_buf_ptr = 0; // invalid
    while(1){
        select{ //Note replicated cases - select across each element of the array
            case i_dbuf.store(BUFFER_TYPE new_val):
              dbuf[input_buf][input_idx] = new_val; 
              input_idx++;
              if(input_idx>=BUF_SIZE) {
                // input buffer is full. -> Swap the buffers

                // input buffer will be output buffer after swap
                output_buf_ptr = &dbuf[input_buf][0]; // update pointer 
                i_dbuf_swap.sync(output_buf_ptr); // send pointer to other task and synchronise
                
                // flip input buffer
                input_buf = 1 - input_buf;                
                input_idx=0;

                //printf("Double Buffer was swapped\n");
              }
              break;

        }
    }
}

extern int process_buffer(BUFFER_TYPE * unsafe buffer);

void dsp_task(server interface dbuf_ptr_if i_dbuf_swap) {

   BUFFER_TYPE * unsafe buf=0; // invalid

   while(1) {
       select {
           case i_dbuf_swap.sync(BUFFER_TYPE * unsafe &buf_ptr):
               buf = buf_ptr;
               // new buffer is valid. Now process it
               process_buffer(buf);
               //if(buf[0] > 4*BUF_SIZE) return;
               break;
       }
   }
}
}


int main() {

    i2s_frame_callback_if i_i2s;
    i2c_master_if i_i2c[1];
    chan c_audio;
    interface dbuf_store_if i_dbuf;
    interface dbuf_ptr_if i_dbuf_swap;

    par {
        on tile[1]: {
          //configure_clock_src(mclk, p_mclk_in1);
          //start_clock(mclk);
          i2s_frame_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, p_mclk_in1, bclk);
        }

        on tile[1]: [[distribute]]i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
        on tile[1]: [[distribute]]i2s_handler(i_i2s, i_i2c[0], c_audio, i_dbuf);
        on tile[1]: [[distribute]]double_buffer(i_dbuf, i_dbuf_swap);

        on tile[1]: dsp_task(i_dbuf_swap);

        on tile[0]: {
            configure_clock_src_divide(pdmclk, p_mclk, MASTER_TO_PDM_CLOCK_DIVIDER);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_pdm_to_hires[2];
            streaming chan c_hires_to_dec[2];
            streaming chan c_ds_output[2];
            streaming chan c_cmd;

            interface mabs_led_button_if lb[1];

            par {
                mabs_button_and_led_server(lb, 1, leds, p_buttons);

                mic_array_pdm_rx(p_pdm_mics, c_pdm_to_hires[0], c_pdm_to_hires[1]);
                mic_array_hires_delay(c_pdm_to_hires, c_hires_to_dec, 2, c_cmd);
                mic_array_decimate_to_pcm_4ch(c_hires_to_dec[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
                mic_array_decimate_to_pcm_4ch(c_hires_to_dec[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
                hires_DAS_fixed(c_ds_output, c_cmd, lb[0], c_audio);
            }
            stop_clock(pdmclk);
        }
    }

    return 0;
}
