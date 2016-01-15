// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include "mic_array.h"
#include "mic_array_board_support.h"
#include "lib_dsp_transforms.h"
#include <stdio.h>
#include <stdlib.h>
#include <xclib.h>

on tile[0]:p_leds leds = DEFAULT_INIT;
on tile[0]:in port p_buttons =  XS1_PORT_4A;

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

//This sets the FIR decimation factor.
#define DF 6

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_complex audio[2];

void example(streaming chanend c_ds_output[2],
        client interface led_button_if lb){
    unsigned buffer;

    unsafe{
        decimator_config_common dcc = {MAX_FRAME_SIZE_LOG2, 1, 0, 0, DF, g_third_stage_div_6_fir, 0, 0};
        decimator_config dc[2] = {
                {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };
        decimator_configure(c_ds_output, 2, dc);
    }
    decimator_init_complex_frame(c_ds_output, 2, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

    timer t;
    unsigned time;
    t:> time;
    while(1){

        frame_complex *  current = decimator_get_next_complex_frame(c_ds_output, 2, buffer, audio, 2);

        int max = current->metadata[0].max;
        if( current->metadata[1].max > current->metadata[0].max) max= current->metadata[1].max;

        if(max < 0 ) max = - max;
        unsigned shift = clz(max) - 1;
        for(unsigned i=0;i<4;i++){

            for(unsigned j=0;j<(1<<MAX_FRAME_SIZE_LOG2);j++){
                current->data[i][j].re <<=shift;
                current->data[i][j].im <<=shift;
            }

            lib_dsp_fft_forward_complex((lib_dsp_fft_complex_t*)current->data[i], (1<<MAX_FRAME_SIZE_LOG2), lib_dsp_sine_2048);
            lib_dsp_fft_reorder_two_real_inputs((lib_dsp_fft_complex_t*)current->data[i], MAX_FRAME_SIZE_LOG2);
        }

        select {
            case lb.button_event():{
                unsigned button;
                e_button_state pressed;
                lb.get_button_event(button, pressed);

                for(unsigned i=0;i<256;i++){
                    printf("%d\t%d\n", current->data[0][i].re, current->data[0][i].im);
                }
                _Exit(1);

                break;
            }
            default:{
                uint32_t max =0;
                unsigned best =0;

                for(unsigned i=0;i<(1<<(MAX_FRAME_SIZE_LOG2-1));i++){
                    int re = current->data[0][i].re>>17;
                    int im = current->data[0][i].im>>17;
                    int mag = re*re + im*im;
                    if(max < mag){
                        max=mag;
                        best = i;
                    }
                }
                printf("%d\n", (best * 48000/DF)>>MAX_FRAME_SIZE_LOG2);
                break;
            }
        }
    }
}

int main(){
    par{
        on tile[0]:{
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output[2];

            interface led_button_if lb[1];

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            par{
                button_and_led_server(lb, 1, leds, p_buttons);
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
                decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
                example(c_ds_output, lb[0]);
                while(1);
                while(1);
                while(1);
            }
        }
    }
    return 0;
}
