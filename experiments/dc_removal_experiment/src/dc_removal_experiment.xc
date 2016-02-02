// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>
#include <stdlib.h>
#include "debug_print.h"
#include <math.h>

#include "mic_array.h"
#include "mic_array_board_support.h"

//If the decimation factor is changed the the coefs array of decimator_config must also be changed.
#define DF 2    // Decimation Factor

on tile[0]:p_leds leds = DEFAULT_INIT;
on tile[0]:in port p_buttons =  XS1_PORT_4A;

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;


int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];

int dc_elim_model(int x, int &prev_x, long long & y, unsigned shift){
    long long X = (long long)x;
    long long prev_X = (long long)prev_x;

    long long t = X - prev_X;
    y = y - (y>>shift);
    y = y + (t<<16);
    prev_x = x;
    return y>>16;
}

void lores_DAS_fixed(streaming chanend c_ds_output[2],
        client interface led_button_if lb) {

    unsafe{
        unsigned buffer;

        decimator_config_common dcc = {0, 0, 0, 0, DF, g_third_stage_div_2_fir, 0, 0, DECIMATOR_NO_FRAME_OVERLAP, 2};
        decimator_config dc[2] = {
          {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
          {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };
        decimator_configure(c_ds_output, 2, dc);

        decimator_init_audio_frame(c_ds_output, 2, buffer, audio, dcc);

        unsigned sample = 0;
        int x;
        int prev_x = 0;
        long long y = 0;

        int dc_offset = 0;

        unsigned shift = 3;
        xscope_int(0, 0);
        while(sample < 16000*8){

            frame_audio *current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, dcc);
            int output = current->data[0][0];

            output = dc_elim_model(output, prev_x, y, shift);

            if(sample > 128)
                xscope_int(0, output);
            else
                xscope_int(0, 0);


           // if(sample > 64){
                dc_offset = dc_offset - (dc_offset>>8) + output;

                int n = dc_offset;

                if(n<0) n=-n;
                //int n = (n * n)>>8;

                shift = clz(n);
                if(shift>16)
                    shift=16;

           // }

            xscope_int(1, shift);
            xscope_int(2, dc_offset);
            sample++;
        }

        _Exit(1);
    }
}

int main() {

    par{

        on tile[0]: {
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_4x_pdm_mic[2];
            streaming chan c_ds_output[2];

            interface led_button_if lb[1];

            par {
                button_and_led_server(lb, 1, leds, p_buttons);
                pdm_rx(p_pdm_mics, c_4x_pdm_mic[0], c_4x_pdm_mic[1]);
                decimate_to_pcm_4ch(c_4x_pdm_mic[0], c_ds_output[0]);
                decimate_to_pcm_4ch(c_4x_pdm_mic[1], c_ds_output[1]);
                lores_DAS_fixed(c_ds_output, lb[0]);
                par(int i=0;i<3;i++) while(1);
            }
        }
    }
    return 0;
}
