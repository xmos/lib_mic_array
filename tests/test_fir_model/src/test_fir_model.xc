#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <xclib.h>
#include <math.h>
#include <stdlib.h>
#include <print.h>
#include <string.h>

static int pseudo_random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return (int)x;
}

static unsafe int filter(int * unsafe coefs, int * unsafe data, const unsigned length, const int val, unsigned &n){
    long long y = 0;
    data[0] = val;
    for (unsigned i=0; i<length; i++)
        y += (long long)coefs[i] * (long long)data[i];
    for (unsigned i=length-1; i>0; i--)
        data[i] = data[i-1];
    return y>>31;
}
#define DF 12    //12 is the maximum I want to support

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];

#define PI (3.141592653589793)
#define COUNT 8
void model(streaming chanend c_4x_pdm_mic_0,
  streaming chanend c_4x_pdm_mic_1, chanend c_model){
    unsigned second_stage_n=0;
    unsigned third_stage_n=0;
    int second_stage_data[16]={0};
    int third_stage_data[32*DF]={0};
    unsigned x=0x1234;
    unsafe {
        while(1){

            int * unsafe fir;
            int * unsafe debug_fir;
            unsigned df;
            int fir_comp;
            unsigned frame_size_log2;
            unsigned index_bit_reversal;
            c_model :> fir;
            c_model :> debug_fir;
            c_model :> df;
            c_model :> fir_comp;
            c_model :> frame_size_log2;
            c_model :> index_bit_reversal;

            int output[8][16];
            memset(second_stage_data, 0, sizeof(int)*16);
            memset(third_stage_data, 0, sizeof(int)*32*df);
            int val;
                for(unsigned c=0;c<COUNT+2;c++){
                    for(unsigned r=0;r<df;r++){
                        for(unsigned p=0;p<4;p++){
                            int input_sample = pseudo_random(x);
                            for(unsigned i=0;i<4;i++){
                                c_4x_pdm_mic_0 <: input_sample;
                                c_4x_pdm_mic_1 <: input_sample;
                            }
                            val = filter(fir2_debug, second_stage_data, 16, input_sample, second_stage_n);
                        }
                        val = filter(debug_fir, third_stage_data, 32*df, val, third_stage_n);
                    }

                    printf("\tmodel: %3d:%12d\n", c, val);
                    //c_model <: val;
                   // output[m][c] = val;
                }

                for(unsigned i=0;i<4*3;i++){
                    c_4x_pdm_mic_0 <: 0;
                    c_4x_pdm_mic_1 <: 0;
                }


                c_model <: 0;

        }
    }

}

#define EXPECTED_FRAMES 1

void output(streaming chanend c_ds_output[2], chanend c_actual){

    unsafe {


        while(1){
        //get the settings from the verifier

        int * unsafe fir;
        int * unsafe debug_fir;
        unsigned df;
        int fir_comp;
        unsigned frame_size_log2;
        unsigned index_bit_reversal;

        c_actual :> fir;
        c_actual :> debug_fir;
        c_actual :> df;
        c_actual :> fir_comp;
        c_actual :> frame_size_log2;
        c_actual :> index_bit_reversal;

        unsigned buffer;

        int output[8][16];

        memset(data_0, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);
        memset(data_1, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);

            unsafe {
               decimator_config_common dcc = {frame_size_log2, 0, index_bit_reversal, 0, df, fir, 0, fir_comp};
               decimator_config dc[2] = {
                       {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                       {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
               };
               decimator_configure(c_ds_output, 2, dc);
            }

           decimator_init_audio_frame(c_ds_output, 2, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

           decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);
           decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);

           for(unsigned c=0;c<COUNT;c++){

                frame_audio *  current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);

                for(unsigned f=0;f<(1<<frame_size_log2);f++){
                    for(unsigned m=0;m<8;m++){
                        output[m][c] = current->data[m][f];
                    }
                    printf("\t\tactual: %3d:%12d\n", c, current->data[0][f]);
                }

           }
           c_actual <: 0;
    }
    }
}

void send_settings(chanend  c_chan,
        int * unsafe fir, int * unsafe debug_fir, unsigned df, int fir_comp,
        unsigned frame_size_log2, unsigned index_bit_reversal){
    unsafe{
        c_chan <: fir;
        c_chan <: debug_fir;
        c_chan <: df;
        c_chan <: fir_comp;
        c_chan <: frame_size_log2;
        c_chan <: index_bit_reversal;
    }
}

void verifier(chanend c_model,
        chanend c_actual){
    unsafe{

        unsigned decimation_factor_lut[5] = {1*2, 2*2, 3*2, 4*2, 6*2};
        int * unsafe decimation_fir_lut[5] = {
                g_third_48kHz_fir,
                g_third_24kHz_fir,
                g_third_16kHz_fir,
                g_third_12kHz_fir,
                g_third_8kHz_fir,
        };
        int * unsafe decimation_fir_debug_lut[5] = {
                fir3_48kHz_debug,
                fir3_24kHz_debug,
                fir3_16kHz_debug,
                fir3_12kHz_debug,
                fir3_8kHz_debug,
        };

        unsigned fir_comp_lut[4] = {0, INT_MAX>>4, INT_MAX<<4, INT_MAX>>8};
        //TODO manual gain comp
        //TODO dc offset elim
        //TODO channel count
        //TODO windowing function


        for(unsigned decimation_index = 0; decimation_index < 5;decimation_index){
            int * unsafe fir = decimation_fir_lut[decimation_index];
            int * unsafe debug_fir = decimation_fir_debug_lut[decimation_index];
            unsigned df = decimation_factor_lut[decimation_index];


            int fir_comp = INT_MAX>>4;;

            unsigned frame_size_log2=0;

            unsigned index_bit_reversal=0;

            send_settings(c_model, fir, debug_fir, df, fir_comp,
                    frame_size_log2, index_bit_reversal);
            send_settings(c_actual, fir, debug_fir, df, fir_comp,
                    frame_size_log2, index_bit_reversal);

            for(unsigned i=0;i<COUNT;i++){
                int a, m;
                //c_actual:> a;
               // c_model :> m;
               // printf("%12d %12d\n", a, m);
            }
            c_actual:> int;
            c_model :> int;
        }
    }
}

int main(){

    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output[2];

    chan c_model, c_actual;

    par {
        model(c_4x_pdm_mic_0, c_4x_pdm_mic_1, c_model);
        decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
        decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
        output(c_ds_output, c_actual);
        verifier(c_model, c_actual);
     }
    return 0;
}
