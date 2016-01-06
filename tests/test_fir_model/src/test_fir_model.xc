
#include "mic_array.h"
#include <limits.h>
#include <stdio.h>
#include <xs1.h>
#include <xclib.h>

#include <math.h>
#include <stdlib.h>

int random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return (int)x;
}

int filter(int coefs[], int data[], const unsigned length, const int val, unsigned &n){
    long long y = 0;
    data[n] = val;
    for (unsigned i=0; i<length; i++)
        y += (long long)coefs[i] * (long long)data[((length - i) + n) % length];

    n = (n + 1) % length;
    return y>>31;
}

#define DF 4

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];

#define PI (3.141592653589793)

void tester(streaming chanend c_4x_pdm_mic_0,

  streaming chanend c_4x_pdm_mic_1){
    unsigned second_stage_n=0;
    unsigned third_stage_n=0;
    int second_stage_data[16]={0};
    int third_stage_data[32*DF]={0};

    while(1){
        int val;

        for(unsigned freq = 100; freq < 16000; freq+=100){
            unsigned output_sample_counter = 0;
            unsigned input_sample_counter = 0;

            int min = 0;
            int max = 0;

            while(output_sample_counter < (384000*2/freq + (THIRD_STAGE_COEFS_PER_STAGE)) ){

                for(unsigned r=0;r<DF;r++){
                    for(unsigned p=0;p<4;p++){
                        double theta = input_sample_counter * 2.0 * PI * freq / 384000;
                        int input_sample = (int)(INT_MAX * sin(theta));
                        input_sample_counter++;
                        val = filter(fir2_debug, second_stage_data, 16, input_sample, second_stage_n);
                    }
                    val = filter(fir3_24kHz_debug, third_stage_data, 32*DF, val, third_stage_n);
                }

                output_sample_counter++;
                if(output_sample_counter > THIRD_STAGE_COEFS_PER_STAGE){
                    if(val > max)
                        max = val;
                    if(val < min)
                        min = val;
                }
            }
            printf("%d %d %d\n",freq, min, max);
        }
        _Exit(1);
    }
}

void output( streaming chanend c_ds_output_0,
        streaming chanend c_ds_output_1){
    unsigned buffer;
    unsafe {
       decimator_config_common dcc = {FRAME_SIZE_LOG2, 0, 0, 0, 2, g_third_48kHz_fir, 1, INT_MAX/8};
        // decimator_config_common dcc = {FRAME_SIZE_LOG2, 0, 0, 0, 2, g_third_48kHz_fir, 1, FIR_COMPENSATOR_48KHZ/2};
       decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4};
       decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4};
       decimator_configure(c_ds_output_0, c_ds_output_1, dc0, dc1);
    }

   decimator_init_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);
    for(unsigned c=0;c<40;c++){
        frame_audio *  current = decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio, 2);

       // for(unsigned i=0;i<8;i++)
        //    printf("%f ", (double)current->data[i][0] / (double) INT_MAX);
        //printf("\n");
       // printf("%f\n", (double)current->data[0][0] / (double) INT_MAX);
       // delay_milliseconds(5);
    }

}


int main(){

    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output_0, c_ds_output_1;

    par {
        tester(c_4x_pdm_mic_0, c_4x_pdm_mic_1 );
        decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
        decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
        output(c_ds_output_0, c_ds_output_1);
     }
    return 0;
}
