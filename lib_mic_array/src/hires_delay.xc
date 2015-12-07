// Copyright (c) 2015, XMOS Ltd, All rights reserved
#include <xs1.h>

#include "mic_array.h"
#include <string.h>

void hires_delay(
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1,
        streaming chanend c_sync,
        hires_delay_config * unsafe config,
        int64_t * unsafe p_shared_memory_array){


    unsafe {

        unsigned char * unsafe mic_array = (unsigned char * unsafe)p_shared_memory_array;
        unsigned index = 0;

        while(1){
            int t;
            asm volatile("inct %0, res[%1]":"=r"(t):"r"(c_sync));
            unsigned v=0, q=0;
            unsigned current_set = config->active_delay_set;

            //to limit the reloading of delays
            for(unsigned i=0;i<1;i++){

                v += mic_array[zext(index-config->delays[current_set][0], config->memory_size_log2) * 8 + 0];
                v<<=8;
                v += mic_array[zext(index-config->delays[current_set][1], config->memory_size_log2) * 8 + 1];
                v<<=8;
                v += mic_array[zext(index-config->delays[current_set][2], config->memory_size_log2) * 8 + 2];
                v<<=8;
                v += mic_array[zext(index-config->delays[current_set][3], config->memory_size_log2) * 8 + 3];

                q += mic_array[zext(index-config->delays[current_set][4], config->memory_size_log2) * 8 + 4];
                q<<=8;
                q += mic_array[zext(index-config->delays[current_set][5], config->memory_size_log2) * 8 + 5];
                q<<=8;
                q += mic_array[zext(index-config->delays[current_set][6], config->memory_size_log2) * 8 + 6];
                q<<=8;
                q += mic_array[zext(index-config->delays[current_set][7], config->memory_size_log2) * 8 + 7];

                index++;

                c_4x_pdm_mic_0 <: v;
                c_4x_pdm_mic_1 <: q;
            }
        }
    }
}

int hires_delay_set_taps(hires_delay_config * unsafe config,
        unsigned delays[], unsigned num_taps){
    unsafe{
        unsigned active_set = config->active_delay_set;
        unsigned next = config->delay_set_head;

        if(next == active_set){
            next++;
            next %= HIRES_DELAY_TAP_COUNT;
            memcpy(config->delays[next], delays, sizeof(unsigned)*num_taps);
            config->delay_set_head = next;
        } else {
            next++;
            next %= HIRES_DELAY_TAP_COUNT;
            if(next == active_set){
                return 1;
            } else {
                memcpy(config->delays[next], delays, sizeof(unsigned)*num_taps);
                config->delay_set_head = next;
            }
        }
    }
    return 0;
}

