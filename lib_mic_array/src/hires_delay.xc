// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
#include <xs1.h>

#include "mic_array.h"
#include <string.h>

unsigned g_hires_shared_memory[16];

#define MICS_PER_S_CHAN 4

#pragma unsafe arrays
void mic_array_hires_delay(
        streaming chanend c_from_pdm_frontend[],
        streaming chanend c_to_decimator[],
        unsigned n,
        streaming chanend c_cmd){

    unsigned delays[16] = {0};
    int data[16][MIC_ARRAY_HIRES_MAX_DELAY];
    memset(data, 0, sizeof(int)*16*MIC_ARRAY_HIRES_MAX_DELAY);

    unsigned head = 0;
    while(1){
        for(unsigned i=0;i<MICS_PER_S_CHAN;i++){
            for(unsigned j=0;j<n;j++){
                c_from_pdm_frontend[j] :> data[i+j*MICS_PER_S_CHAN][head];
            }
        }

        for(unsigned i=0;i<MICS_PER_S_CHAN;i++){
            for(unsigned j=0;j<n;j++){
                c_to_decimator[j] <:
                    data[i+j*MICS_PER_S_CHAN][(head-delays[i+j*MICS_PER_S_CHAN])%MIC_ARRAY_HIRES_MAX_DELAY];
            }
        }
        head++;
        if (head == MIC_ARRAY_HIRES_MAX_DELAY)
            head = 0;

        select {
            case c_cmd :> unsigned n :{
                for(unsigned i=0;i<n;i++){
                    unsafe {
                        unsigned * unsafe p = g_hires_shared_memory;
                        delays[i] =p[i];
                    }

                }
                break;
            }
            default: break;
        }
    }
}

#pragma unsafe arrays
void mic_array_hires_delay_set_taps(streaming chanend c_cmd,
        unsigned delays[], unsigned num_channels){
    for(unsigned i=0;i<num_channels;i++){
       unsigned d;
        if(delays[i] < MIC_ARRAY_HIRES_MAX_DELAY)
            d = delays[i];
        else
            d = MIC_ARRAY_HIRES_MAX_DELAY-1;
        unsafe {
            unsigned * unsafe p = g_hires_shared_memory;
            p[i] = d;
        }
    }
    c_cmd <: num_channels;
}

