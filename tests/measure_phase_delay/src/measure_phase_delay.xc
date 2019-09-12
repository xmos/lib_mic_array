// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>

#include "mic_array.h"

#include "i2c.h"
#include "i2s.h"

unsigned g_mem = 0;

#define DF 12    //Decimation Factor

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

int data[4][THIRD_STAGE_COEFS_PER_STAGE*DF];

void test_output(streaming chanend c_ds_output[1]){
    unsafe{
        unsigned df[5] = {2, 4, 6, 8, 12};
        int comp [5] = {
                FIR_COMPENSATOR_DIV_2,
                FIR_COMPENSATOR_DIV_4,
                FIR_COMPENSATOR_DIV_6,
                FIR_COMPENSATOR_DIV_8,
                FIR_COMPENSATOR_DIV_12,
        };

        int * unsafe coefs [5] = {
                g_third_stage_div_2_fir,
                g_third_stage_div_4_fir,
                g_third_stage_div_6_fir,
                g_third_stage_div_8_fir,
                g_third_stage_div_12_fir,
        };

        mic_array_frame_time_domain audio[2];

        unsigned buffer;     //buffer index
        memset(data, 0, sizeof(data));

        for(unsigned index = 0; index < 5;index ++){
            unsigned max_count = 0;

            for(unsigned run = 0; run < 64;run ++){
                mic_array_decimator_conf_common_t dcc = {0, 0, 0, 0, df[index],
                        coefs[index], 0, comp[index],
                        DECIMATOR_NO_FRAME_OVERLAP, 2};
                mic_array_decimator_config_t dc[1] = {{&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0}};

                mic_array_decimator_configure(c_ds_output, 1, dc);

                mic_array_init_time_domain_frame(c_ds_output, 1, buffer, audio, dc);

                for(unsigned i=0;i<64;i++)
                    mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc)->data[0][0];

                asm volatile("");
                g_mem = 0xffffffff;
                asm volatile("");
                unsigned count = 0;
                int v =-1;
                while(v<0){
                    mic_array_frame_time_domain *  current = mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc);
                    v = current->data[0][0];
                    count++;
                }
                asm volatile("");
                g_mem = 0;
                asm volatile("");
                for(unsigned i=0;i<64;i++)
                    mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc);

                if(count > max_count)
                    max_count = count;

            }
            printf("%d Hz -> %3d samples phase delay\n", 96000/df[index], max_count);
        }
    }
    _Exit(1);
}


extern void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

int main(){

    configure_clock_src_divide(pdmclk, p_mclk, 4);
    configure_port_clock_output(p_pdm_clk, pdmclk);
    configure_in_port(p_pdm_mics, pdmclk);
    start_clock(pdmclk);

    streaming chan c_4x_pdm_mic_0;
    streaming chan c_ds_output[1];
    streaming chan not_a_port;

    par{

        while(1){
            unsigned t;
            unsafe {
                p_pdm_mics :> int;  //for synchronisation
                asm volatile ("ldw %0, cp[g_mem]; out res[%1], %0": "=r"(t): "r"(not_a_port));

            }
        }

        pdm_rx_debug(not_a_port, c_4x_pdm_mic_0, null);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        test_output(c_ds_output);
        par(int i=0;i<4;i++)while(1);
    }

    return 0;
}
