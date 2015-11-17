#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>

#include "sine_lut.h"
#include "fir_decimator.h"
#include "mic_array.h"
#include "mic_array_board_support.h"

#include "i2c.h"
#include "i2s.h"

#define DF 1    //Decimation Factor

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



int data_0[4*COEFS_PER_PHASE*DF] = {0};
int data_1[4*COEFS_PER_PHASE*DF] = {0};
frame_audio audio[2];

#define PI (3.14159265358979323846264338327950288419716939937510582097494459230781)
#define NUM_MICS 7
#define R 0.025
#define THETA (2.0*PI/6)
static const double mic_theta_coords[NUM_MICS] = {0.0*THETA, 1.0*THETA, 2.0*THETA, 3.0*THETA, 4.0*THETA, 5.0*THETA, 0.0};
static const double mic_phi_coords[NUM_MICS]   = {PI/2.0, PI/2.0, PI/2.0, PI/2.0, PI/2.0, PI/2.0, 0.0};
static const double mic_r_coords[NUM_MICS]     = {R, R, R, R, R, R, 0.0};

//This represents 1m or 2pi
#define SCALE_FACTOR (1<<24)

 {int, int, int} static polar_to_cart(double r, double theta, double phi){
    double X = r*sin(phi)*cos(theta)*SCALE_FACTOR;
    double Y = r*sin(phi)*sin(theta)*SCALE_FACTOR;
    double Z = r*cos(phi)*SCALE_FACTOR;

    int x = (int)X;
    int y = (int)Y;
    int z = (int)Z;

    y=y%SCALE_FACTOR;
    z=z%SCALE_FACTOR;

    return {x, y, z};
}

 {double, double, double} static cart_to_polar(int x, int y, int z){
    double X = (double)x;
    double Y = (double)y;
    double Z = (double)z;

    X /= (double)SCALE_FACTOR;
    Y /= (double)SCALE_FACTOR;
    Z /= (double)SCALE_FACTOR;

    double r = sqrt(X*X + Y*Y + Z*Z);
    double theta = atan2(Y, X);
    double phi = atan2(sqrt(X*X + Y*Y), Z);

    //if(theta < 2.0*PI) theta += 2.0*PI;
    //if(phi < 2.0*PI) phi += 2.0*PI;

    return {r, theta, phi};
}

void calc_taps(chanend c_calc){

    int theta;
    int phi;
    int r;
    unsigned tap[7] = {0};

    while(1){
        //input
        c_calc :> theta;
        c_calc :> phi;
        c_calc :> r;

        //get busy





        //output
        for(unsigned i=0;i<7;i++)
            c_calc <: tap[i];
    }


}


void delay_tester(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
        client interface led_button_if lb, chanend c_audio, chanend c_calc){

    unsigned buffer = 1;     //buffer index
    memset(audio, sizeof(frame_audio), 0);


    for(int i=0;i<NUM_MICS;i++){

        printf("%.5f %.5f %.5f -> ", mic_r_coords[i], mic_theta_coords[i], mic_phi_coords[i]);
        int x, y, z;
        {x, y, z} = polar_to_cart(mic_r_coords[i], mic_theta_coords[i], mic_phi_coords[i]);

        printf("%11d %11d %11d -> ", x, y, z);
        double r, theta, phi;
        {r, theta, phi} = cart_to_polar(x, y, z);
        printf("%.5f %.5f %.5f\n", r, theta, phi);

    }
    _Exit(1);
#define MAX_DELAY 128
    int delay_buffer[MAX_DELAY][7];
    unsigned delay_head = 0;

    unsigned decimation_factor=DF;
    unsafe{
        decimator_config_common dcc = {FRAME_SIZE_LOG2, 1, 0, 0, decimation_factor, fir_coefs[decimation_factor], 0};
        decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
        decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
        decimator_configure(c_ds_output_0, c_ds_output_1, dc0, dc1);
    }

    decimator_init_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio);


    unsigned taps[7] = {0};
    int x=0, y=0, z=0;
    while(1){

        int done = 0;

        int rms = 0;

        memset(delay_buffer, 0, sizeof(int)*8*8);

        while(!done){

            unsigned N = 1000;
            for(unsigned sample = 0;sample < N; sample ++){
                frame_audio *  current = decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio);
                for(unsigned i=0;i<7;i++)
                   delay_buffer[delay_head][i] = current->data[i][0];

                int output = 0;
                for(unsigned i=0;i<7;i++)
                    output += delay_buffer[(delay_head - taps[i])%MAX_DELAY][i];

                rms += output;
            }
        }


        //send the request to the
        c_calc <: x;
        c_calc <: y;
        c_calc <: z;
        while(1){
            select {
                case c_calc :> taps[0]:{
                    for(unsigned i=1;i<7;i++)
                        c_calc :> taps[i];
                        //set the taps
                    break;
                }
                default:
                    decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio);
                    break;
            }

        }




    }
}

#define DF 1

#define OUTPUT_SAMPLE_RATE (48000/DF)
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

void sine_generator(chanend c_audio, chanend c_sine_command){
    unsigned theta = 0;
    unsigned freq = 1000;
    while(1){
        int v=sine_lut_sin_xc(theta)<<16;
        c_audio <: v;
        c_audio <: v;
        theta += ((freq<<16) / OUTPUT_SAMPLE_RATE);
        theta &= SINE_LUT_INPUT_MASK;
        select {
            case c_sine_command :> freq : break;
            default:break;
        }
    }
}

int main(){

    i2s_callback_if i_i2s;
    i2c_master_if i_i2c[1];
    chan c_audio;
    chan c_calc;
    chan c_sine_command;
    par{

        on tile[1]: {
          configure_clock_src(mclk, p_mclk_in1);
          start_clock(mclk);
          i2s_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, bclk, mclk);
        }

        on tile[1]:  [[distribute]]i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
        on tile[1]:  [[distribute]]i2s_handler(i_i2s, i_i2c[0], c_audio);
        on tile[1]:  sine_generator(c_audio, c_sine_command);
        on tile[1]:  calc_taps(c_calc);

        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;

            interface led_button_if lb;

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            par{
                button_and_led_server(lb, leds, p_buttons);
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
                decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
                delay_tester(c_ds_output_0, c_ds_output_1, lb, c_sine_command, c_calc);
            }
        }
    }
    return 0;
}

