#include <xs1.h>

void hires_delay(
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1,
        streaming chanend c_sync,
        unsigned ch_memory_depth_log2,
        unsigned long long * unsafe p_taps,
        unsigned long long * unsafe p_shared_memory_array){

    unsafe {

        unsigned char * unsafe mic_array = (unsigned char * unsafe)p_shared_memory_array;
        unsigned index = 0;

        while(1){
            int t;
            asm("inct %0, res[%1]":"=r"(t):"r"(c_sync));
            unsigned v=0, q=0;
            v += mic_array[((index-p_taps[0]) * 8 + 0)];
            v<<=8;
            v += mic_array[((index-p_taps[1]) * 8 + 1)];
            v<<=8;
            v += mic_array[((index-p_taps[2]) * 8 + 2)];
            v<<=8;
            v += mic_array[((index-p_taps[3]) * 8 + 3)];

            q += mic_array[((index-p_taps[4]) * 8 + 4)];
            q<<=8;
            q += mic_array[((index-p_taps[5]) * 8 + 5)];
            q<<=8;
            q += mic_array[((index-p_taps[6]) * 8 + 6)];
            q<<=8;
            q += mic_array[((index-p_taps[7]) * 8 + 7)];

            c_4x_pdm_mic_0 <: v;
            c_4x_pdm_mic_1 <: q;
        }
    }
}
