// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xscope.h>
#include <xs1.h>
#include <xclib.h>
#include "mic_array_board_support.h"
#include "lib_dsp_transforms.h"
#include <print.h>
#include <stdint.h>
#include <stdlib.h>

on tile[0]:p_leds leds = DEFAULT_INIT;
on tile[0]:in port p_buttons =  XS1_PORT_4A;

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:8  p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

#define N 13

extern const int window[1<<(N-1)];
#include <stdio.h>

void maxer(streaming chanend c_a, streaming chanend  c_c,
        client interface led_button_if lb){
    unsafe {
    long long x[2];
    lib_dsp_fft_complex_t pts[3][1<<N];
    lib_dsp_fft_complex_t * unsafe pt[3] = {pts[0], pts[1], pts[2]};

    c_a <: pt[0];
    c_a <: pt[1];
    c_a <: pt[2];

    uint64_t mag_max[1<<(N-1)]= {0};

    lib_dsp_fft_complex_t * unsafe p;
    while(1){
        c_c :> p;
        for(unsigned i=1;i<1<<(N-1);i++){
            uint64_t mag = (int64_t)p[i].re*(int64_t)p[i].re +  (int64_t)p[i].im*(int64_t)p[i].im;
            if (mag_max[i] < mag)
                mag_max[i] = mag;
        }

        select {
            case lb.button_event():{
                unsigned button;
                e_button_state pressed;
                lb.get_button_event(button, pressed);
                if(pressed == 1){
                    for(unsigned i=1;i<1<<(N-1);i++){
                        printullongln(mag_max[i]);
                        delay_milliseconds(4);
                    }
                }
                break;
            }
            default: break;
        }
        c_a <: p;
    }
}
}


int main(){

    configure_clock_src_divide(pdmclk, p_mclk, 4);
    configure_port_clock_output(p_pdm_clk, pdmclk);
    configure_in_port(p_pdm_mics, pdmclk);
    start_clock(pdmclk);

    streaming chan c_a, c_b, c_c;

    interface led_button_if lb[1];
    par {
        //input-er
        unsafe {
            lib_dsp_fft_complex_t * unsafe p;

           while(1){
               c_a :> p;
               for(unsigned i=0;i<(1<<N);i++){
                   unsigned v;
                   p_pdm_mics :> v;
                   v&=2;
                   unsigned j=i;
                   if ( i>>(N-1))
                       j = ((1<<N)-1)-j;
                   int w = window[j];
                   if(v!=0)
                       p[i].re =  w;
                   else
                       p[i].re = -w;
                   p[i].im = 0;
               }
               c_b <: p;
           }
        }
        //fft-er
        unsafe {
            lib_dsp_fft_complex_t * unsafe p;
            while(1){
                c_b :> p;
                lib_dsp_fft_bit_reverse((lib_dsp_fft_complex_t *)p, 1<<N);
                lib_dsp_fft_forward_complex((lib_dsp_fft_complex_t *)p, (1<<N), lib_dsp_sine_8192);
                c_c <: p;
            }
        }
        button_and_led_server(lb, 1, leds, p_buttons);
        //max-er
        maxer(c_a, c_c, lb[0]);
    }
    return 0;
}
