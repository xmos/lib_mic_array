// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>

out port p_out  = XS1_PORT_8A;

in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
clock pdmclk                    = XS1_CLKBLK_1;

void test8ch_frontend(){
    streaming chan c, d;
    par {
        {
            configure_clock_ref(pdmclk, 10);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);
            mic_array_pdm_rx(p_pdm_mics, c, d);
        }
        {
            p_out <: 0;
            int initial = 0;
            for(unsigned i=0;i<4;i++){
                c :> initial;
                d :> initial;
            }
            for(unsigned ch=0;ch<8;ch++){
                p_out <: 1<<ch;
                unsigned count = 0;
                int stable = 0;
                int vals[8] = {0};
                while((!stable) || (count < 12)){
                    int changed = 0;
                    int new_vals[8];
                    for(unsigned i=0;i<4;i++){
                       c :> new_vals[i];
                       d :> new_vals[i+4];
                    }
                    for(unsigned i=0;i<8;i++){
                        if(vals[i] != new_vals[i]){
                            changed = 1;
                            vals[i] = new_vals[i];
                        }
                    }
                    if(!changed)
                        stable = 1;

                    count++;
                }
                printf("Pin %d -> Channel ",ch);
                //printf("*Channel %d -> Pin ",ch);
                for(unsigned i=0;i<8;i++){
                    int diff =  vals[i]-initial;
                    if(diff)
                        printf("%d ", i);
                }
                printf("\n");
            }
            _Exit(0);
        }
    }
}
void test4ch_frontend(){
    streaming chan c;
    par {
        {
            configure_clock_ref(pdmclk, 10);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);
            mic_array_pdm_rx(p_pdm_mics, c, null);
        }
        {
            p_out <: 0;
            int initial = 0;
            for(unsigned i=0;i<4;i++)
                c :> initial;

            for(unsigned ch=0;ch<8;ch++){
                p_out <: 1<<ch;
                unsigned count = 0;
                int stable = 0;
                int vals[4] = {0};
                while((!stable) || (count < 12)){
                    int changed = 0;
                    int new_vals[4];
                    for(unsigned i=0;i<4;i++){
                       c :> new_vals[i];
                    }
                    for(unsigned i=0;i<4;i++){
                        if(vals[i] != new_vals[i]){
                            changed = 1;
                            vals[i] = new_vals[i];
                        }
                    }
                    if(!changed)
                        stable = 1;

                    count++;
                }
                printf("Pin %d -> Channel ",ch);
                //printf("Channel %d -> Pin ",ch);
                for(unsigned i=0;i<4;i++){
                    int diff =  vals[i]-initial;
                    if(diff)
                        printf("%d ", i);
                }
                printf("\n");
            }
            _Exit(0);
        }
    }
}

int data[4*THIRD_STAGE_COEFS_PER_STAGE*2] = {0};
void test4ch_backend(){

    streaming chan c_pdm_to_dec;
    streaming chan c_ds_output[1];
    par {
        {
            unsigned N = 48*8;
            c_pdm_to_dec <: 0x7fffffff;
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0;

            for(unsigned i=0;i<N;i++){
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
            }
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0x7fffffff;
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0;

            for(unsigned i=0;i<N;i++){
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
            }
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0x7fffffff;
            c_pdm_to_dec <: 0;

            for(unsigned i=0;i<N;i++){
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
            }
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0;
            c_pdm_to_dec <: 0x7fffffff;

            for(unsigned i=0;i<N;i++){
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
                c_pdm_to_dec <: 0;
            }
            _Exit(0);
        }
        mic_array_decimate_to_pcm_4ch(c_pdm_to_dec, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        {
            unsafe{
                mic_array_frame_time_domain audio[2];
                unsigned buffer;
                mic_array_decimator_conf_common_t dcc = {0, 0, 0, 0, 2, g_third_stage_div_2_fir, 0, 0, DECIMATOR_NO_FRAME_OVERLAP, 2  };
                mic_array_decimator_config_t dc[1] = { { &dcc, data, { INT_MAX, INT_MAX, INT_MAX, INT_MAX }, 4, 0}};
                mic_array_decimator_configure(c_ds_output, 1, dc);
                mic_array_init_time_domain_frame(c_ds_output, 1 , buffer, audio, dc);

                int last_seen = -1;
                while(1){
                    mic_array_frame_time_domain *current = mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc);

                    int all_zero = 1;
                    int active_channel = -1;
                    for(unsigned i=0;i<4;i++){
                        all_zero &= (current->data[i][0] ==0);
                        if(current->data[i][0] != 0){
                            if(active_channel >= 0){
                                printf("Error: two channels active at the same time\n");
                                _Exit(1);
                            } else {
                                active_channel = i;
                            }
                        }
                    }

                    if(!all_zero){
                        if(active_channel != last_seen){
                            printf("channel: %d\n", active_channel);
                            last_seen = active_channel;
                        }
                    }
                }
            }
        }
    }

}

int main(){

#ifdef FRONTEND_8BIT_4CH
    test4ch_frontend();
#endif

#ifdef FRONTEND_8BIT_8CH
     test8ch_frontend();
#endif

#ifdef BACKEND
    test4ch_backend();
#endif
    return 0;
}
