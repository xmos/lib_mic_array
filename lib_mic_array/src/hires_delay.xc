// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xs1.h>

#include "mic_array.h"
#include <string.h>

#ifndef HIRES_MAX_DELAY
    #define HIRES_MAX_DELAY 32
#endif

#pragma unsafe arrays
void hires_delay(
        streaming chanend c_from_pdm_frontend[],
        streaming chanend c_to_decimator[],
        unsigned n,
        chanend c_cmd){

    unsigned delays[8] = {0};
    int data[8][HIRES_MAX_DELAY];
    memset(data, 0, sizeof(int)*8*HIRES_MAX_DELAY);

    unsigned head = 0;
    while(1){
        for(unsigned i=0;i<4;i++){
            c_from_pdm_frontend[0] :> data[i*2][head];
            c_from_pdm_frontend[1] :> data[i*2+1][head];
        }
        for(unsigned i=0;i<4;i++){
            c_to_decimator[0] <: data[i*2][(head-delays[2*i])%HIRES_MAX_DELAY];
            c_to_decimator[1] <: data[i*2+1][(head-delays[2*i+1])%HIRES_MAX_DELAY];
        }
        head++;
        if (head == HIRES_MAX_DELAY)
            head = 0;

        select {
            case c_cmd :> int cmd :{
                slave{
                    for(unsigned i=0;i<8;i++){
                        c_cmd :> delays[i];
                    }
                }
                break;
            }
            default: break;
        }
    }
}

#pragma unsafe arrays
void hires_delay_set_taps(chanend c_cmd, unsigned delays[], unsigned num_channels){
    c_cmd <: 0;
    master{
        for(unsigned i=0;i<num_channels;i++){
            if(delays[i] < HIRES_MAX_DELAY)
                c_cmd <: delays[i];
            else
                c_cmd <: HIRES_MAX_DELAY-1;
        }
    }
}

