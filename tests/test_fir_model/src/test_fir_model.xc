
#include "mic_array.h"
#include <limits.h>
#include <stdio.h>
#include <xs1.h>
#include <xclib.h>
#include <math.h>
#include <stdlib.h>
#include <print.h>

static int pseudo_random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return (int)x;
}

#define TEST_SEQUENCE_LENGTH 4096


static int filter2(int coefs[], int data[], const unsigned length, const int val, unsigned &n){
    long long y = 0;
    data[n] = val;
    for (unsigned i=0; i<length; i++)
        y += (long long)coefs[i] * (long long)data[((length - i) + n) % length];
    //n = (n + 1) % length;
    if((n+1) == length){
        n=0;
    } else {
        n++;
    }
    return y>>31;
}


static int filter(int coefs[], int data[], const unsigned length, const int val, unsigned &n){
    long long y = 0;
    data[0] = val;
    for (unsigned i=0; i<length; i++)
        y += (long long)coefs[i] * (long long)data[i];
    for (unsigned i=length-1; i>0; i--)
        data[i] = data[i-1];
    return y>>31;
}
#define DF 2    //12 is the maximum I want to support

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];

#define PI (3.141592653589793)

void model(streaming chanend c_4x_pdm_mic_0,
  streaming chanend c_4x_pdm_mic_1, streaming chanend c_model){
    unsigned second_stage_n=0;
    unsigned third_stage_n=0;
    int second_stage_data[16]={0};
    int third_stage_data[32*DF]={0};
#if 1
    while(1){
        int val;

        for(unsigned freq = 10; freq < 16000; freq+=10){
            unsigned output_sample_counter = 0;
            unsigned input_sample_counter = 0;
            while(output_sample_counter < (384000*2/freq + (THIRD_STAGE_COEFS_PER_STAGE)) ){

                for(unsigned r=0;r<DF;r++){
                    for(unsigned p=0;p<4;p++){
                        double theta = input_sample_counter * 2.0 * PI * freq / 384000;
                        int input_sample = (int)(INT_MAX * sin(theta));
                        for(unsigned i=0;i<4;i++){
                            c_4x_pdm_mic_0 <: input_sample;
                            c_4x_pdm_mic_1 <: input_sample;
                        }
                        input_sample_counter++;
                        val = filter(fir2_debug, second_stage_data, 16, input_sample, second_stage_n);
                    }
                    val = filter(fir3_48kHz_debug, third_stage_data, 32*DF, val, third_stage_n);
                }

                c_model <: val;

                output_sample_counter++;
            }
        }
        _Exit(1);
    }
#else

    unsigned x=0x1234;
    while(1){
        int val;
        while(1 ){

            for(unsigned r=0;r<DF;r++){
                for(unsigned p=0;p<4;p++){
                    int input_sample = pseudo_random(x);
                    for(unsigned i=0;i<4;i++){
                        c_4x_pdm_mic_0 <: input_sample;
                        c_4x_pdm_mic_1 <: input_sample;
                    }
                    val = filter(fir2_debug, second_stage_data, 16, input_sample, second_stage_n);
                }
                val = filter(fir3_48kHz_debug, third_stage_data, 32*DF, val, third_stage_n);
            }
            c_model <: val;
        }
    }
#endif
}

void output( streaming chanend c_ds_output_0,
        streaming chanend c_ds_output_1, streaming chanend c_actual){
    unsigned buffer;
    unsafe {
       decimator_config_common dcc = {FRAME_SIZE_LOG2, 0, 0, 0, 2, g_third_48kHz_fir, 1, INT_MAX>>4};
       decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4};
       decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4};
       decimator_configure(c_ds_output_0, c_ds_output_1, dc0, dc1);
    }

   decimator_init_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);
   decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio, 2);
   decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio, 2);
   while(1){
        frame_audio *  current = decimator_get_next_audio_frame(c_ds_output_0, c_ds_output_1, buffer, audio, 2);
        c_actual <: current->data[0][0];
    }
}

void send_settings(streaming chanend  c_chan,
        int * fir, unsigned df, int fir_comp,
        unsigned frame_size_log2, unsigned index_bit_reversal){

}

void verifier(streaming chanend c_model,
        streaming chanend c_actual){

#if 0

    unsigned decimation_factor_lut[5] = {1*2, 2*2, 3*2, 4*2, 6*2};
    int * decimation_fir_lut[5] = {
            g_third_48kHz_fir,
            g_third_24kHz_fir,
            g_third_16kHz_fir,
            g_third_12kHz_fir,
            g_third_8kHz_fir,
    };

    unsigned fir_comp_lut[4] = {0, INT_MAX>>4, INT_MAX<<4, INT_MAX>>8};
    //TODO manual gain comp
    //TODO dc offset elim
    //TODO channel count
    //TODO windowing function

    for(unsigned decimation_index = 0; decimation_index < 5;decimation_index++){
        int * fir = decimation_fir_lut[decimation_index];
        unsigned df = decimation_factor_lut[decimation_index];
        for(unsigned fir_comp_index = 0; fir_comp_index<4; fir_comp_index++){
            int fir_comp = fir_comp_lut[fir_comp_index];
            for(unsigned frame_size_log2=0;frame_size_log2<8;frame_size_log2++){
                for(unsigned index_bit_reversal=0;index_bit_reversal<2;index_bit_reversal++){
                    send_settings(c_model, fir, df, fir_comp, frame_size_log2, index_bit_reversal);
                    send_settings(c_actual, fir, df, fir_comp, frame_size_log2, index_bit_reversal);

                    for(unsigned i=0;i<TEST_SEQUENCE_LENGTH;i++){

                    }
                }
            }
        }
    }
#else
    int max_diff = 0;
    int max = 0, min = -0;
    while(1){
        int m, a;
        c_model :> m;
        c_actual :> a;
        int diff = m-a;

        if(a > max){
            max = a;
            printf("%12d %12d %12d\n", min, max, diff);
        }
        if(a < min){
            min = a;
            printf("%12d %12d %12d\n", min, max, diff);
        }
        if(diff > max_diff){
            max_diff = diff;
            printf("%12d %12d %12d\n", min, max, diff);
        }
    }
#endif
}

int main(){

    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output_0, c_ds_output_1;

    streaming chan c_model, c_actual;

    par {
        model(c_4x_pdm_mic_0, c_4x_pdm_mic_1, c_model);
        decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
        decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
        output(c_ds_output_0, c_ds_output_1, c_actual);
        verifier(c_model, c_actual);
     }
    return 0;
}
