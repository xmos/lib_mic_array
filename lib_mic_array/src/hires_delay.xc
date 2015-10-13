#include <xs1.h>

#include "mic_array.h"

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
