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

#define SAMPLE_RATE 768000.0
#define SPEED_OF_SOUND (342.0)
#define PI (3.14159265358979323846264338327950288419716939937510582097494459230781)
#define NUM_MICS 7
#define R (0.04)
#define THETA (2.0*PI/6.0)

typedef struct {
    double r;
    double theta;
    double phi;
} polar3d;

static const polar3d mic_coords[NUM_MICS] = {
        {0.0, 0.0, 0.0},    //mic 0
        {R, 0.0*THETA + THETA/2.0, PI/2.0},
        {R, 1.0*THETA + THETA/2.0, PI/2.0},
        {R, 2.0*THETA + THETA/2.0, PI/2.0},
        {R, 3.0*THETA + THETA/2.0, PI/2.0},
        {R, 4.0*THETA + THETA/2.0, PI/2.0},
        {R, 5.0*THETA + THETA/2.0, PI/2.0},
};



typedef struct {
    int x;
    int y;
    int z;
} cart;

//This represents 1m or 2pi
#define SCALE_FACTOR (1<<24)

cart static polar3d_to_cart(polar3d p){
    double X = p.r*sin(p.phi)*cos(p.theta)*SCALE_FACTOR;
    double Y = p.r*sin(p.phi)*sin(p.theta)*SCALE_FACTOR;
    double Z = p.r*cos(p.phi)*SCALE_FACTOR;

    int x = (int)X;
    int y = ((int)Y)%SCALE_FACTOR;
    int z = ((int)Z)%SCALE_FACTOR;

    cart c = {x, y, z};
    return c;
}

polar3d static cart_to_polar3d(cart c){
    double X = (double)c.x;
    double Y = (double)c.y;
    double Z = (double)c.z;

    X /= (double)SCALE_FACTOR;
    Y /= (double)SCALE_FACTOR;
    Z /= (double)SCALE_FACTOR;

    double r = sqrt(X*X + Y*Y + Z*Z);
    double theta = atan2(Y, X);
    double phi = atan2(sqrt(X*X + Y*Y), Z);

    //if(theta < 2.0*PI) theta += 2.0*PI;
    //if(phi < 2.0*PI) phi += 2.0*PI;

    polar3d p = {r, theta, phi};
    return p;
}

double get_dist(polar3d a, polar3d b){

    double x0 = a.r*sin(a.phi)*cos(a.theta);
    double x1 = b.r*sin(b.phi)*cos(b.theta);
    double y0 = a.r*sin(a.phi)*sin(a.theta);
    double y1 = b.r*sin(b.phi)*sin(b.theta);
    double z0 = a.r*cos(a.phi);
    double z1 = b.r*cos(b.phi);

    double x = x0-x1;
    double y = y0-y1;
    double z = z0-z1;

    return sqrt(x*x + y*y + z*z);
}

void get_taps(unsigned taps[], polar3d p){

    unsigned time_of_flight_samples[NUM_MICS];
    int min = 0x7fffffff;
    for(unsigned m=0;m<NUM_MICS;m++){
        time_of_flight_samples[m] = (int)(get_dist(mic_coords[m], p) * SAMPLE_RATE / SPEED_OF_SOUND );
        if(min > time_of_flight_samples[m])
            min = time_of_flight_samples[m];
    }

    for(unsigned m=0;m<NUM_MICS;m++)
        taps[m]= time_of_flight_samples[m] - min;
}


void calc_taps(chanend c_calc){
    while(1){
        unsigned taps[7];
        polar3d p;

        //input
        c_calc :> p;

         //get busy
        get_taps(taps, p);

        //output
        for(unsigned m=0;m<NUM_MICS;m++)
            c_calc <: taps[m];
    }
}


void delay_tester(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
        client interface led_button_if lb, chanend c_audio, chanend c_calc){

    unsigned buffer = 1;     //buffer index
    memset(audio, sizeof(frame_audio), 0);

#define MAX_DELAY 128
    int delay_buffer[MAX_DELAY][7];
    unsigned delay_head = 0;
/*
    for(double theta = 0.0; theta < 2.0*PI; theta += (2.0*PI/16.0)){

        polar3d p = {0.04, theta, PI/2.0};
        for(unsigned i=0;i<7;i++)
            printf("%.5f ", get_dist(mic_coords[i], p));
        printf("\n");
    }


    for(double theta = 0.0; theta < 2.0*PI; theta += (2.0*PI/16.0)){

        polar3d p = {0.04, theta, PI/2.0};
        c_calc <: p;

        unsigned taps[7] = {0};
        for(unsigned i=0;i<7;i++){
             c_calc :> taps[i];
             printf("%d ", taps[i]);
        }
        printf("\n");
    }

    _Exit(1);
*/

    unsigned decimation_factor=DF;
    unsafe{
        decimator_config_common dcc = {FRAME_SIZE_LOG2, 1, 0, 0, decimation_factor, fir_coefs[decimation_factor], 0};
        decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
        decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
        decimator_configure(c_ds_output_0, c_ds_output_1, dc0, dc1);
    }

    decimator_init_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio);

    double theta = 0.0;

    for(unsigned i=0;i<192000;i++)
        decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio);

    unsigned taps[7] = {0};
    while(1){

        //send the request to the calculator
        polar3d p = {1.0, theta, PI/4.0};
        c_calc <: p;
        int calc_done = 0;
        while(!calc_done){
            select {
                case c_calc :> taps[0]:{
                    for(unsigned i=1;i<7;i++)
                        c_calc :> taps[i];
                        calc_done = 1;
                    break;
                }
                default:
                    decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio);
                    break;
            }

        }
        unsigned long long rms = 0;

        memset(delay_buffer, 0, sizeof(int)*8*8);



        unsigned N = 48000;
        for(unsigned sample = 0;sample < N; sample ++){
            frame_audio *  current = decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio);
            for(unsigned i=0;i<7;i++)
               delay_buffer[delay_head][i] = current->data[i][0];

            int output = 0;
            for(unsigned i=0;i<7;i++)
                output += delay_buffer[(delay_head - taps[i])%MAX_DELAY][i];

            if(output < 0)
                output = -output;
            rms += output;

            delay_head++;
            delay_head%=MAX_DELAY;
        }

        printf("%f %llu\n", theta, rms);
        theta += (PI/63.0);






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

