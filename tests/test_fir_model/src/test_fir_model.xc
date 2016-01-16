// Copyright (c) 2016, XMOS Ltd, All rights reserved
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

static unsafe int filter(int * unsafe coefs, int * unsafe data, const unsigned length, const int val){
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
frame_complex f_complex[2];

#define COUNT 16

int generate_tail_output_counter(unsigned fsl2, unsigned df){
    if(fsl2==0)
        return 0;
    unsigned v=df*4;
    for(unsigned i=1;i<fsl2;i++)
        v = v*2+df*4;
    return v;
}

int apply_fir_comp(int val, int fir_comp){
    long long v;
    if(fir_comp){
        v = (long long)val;
        v = v * (long long)fir_comp;
        v=v>>27;
    } else {
        v = (long long)val;
    }
    return (int)v;
}

int apply_gain_comp(int val, int gain){
    long long v = (long long)val;
    v = v * (long long)gain;
    v=v>>31;
    return (int)v;
}

unsigned bitreverse(unsigned i, unsigned bits){
    return (bitrev(i) >> (32-bits));
}

void model(streaming chanend c_4x_pdm_mic_0,
  streaming chanend c_4x_pdm_mic_1, chanend c_model){
    int second_stage_data[8][16];
    int third_stage_data[8][32*DF];

    int window[1<<(MAX_FRAME_SIZE_LOG2-1)];
    {
        unsigned x=0x9876543;
        for(unsigned i=0;i<(1<<(MAX_FRAME_SIZE_LOG2-1)); i++)
            window[i] = pseudo_random(x);
    }

    unsigned x=0x1234;
    unsafe {
        while(1){

            int * unsafe fir;
            int * unsafe debug_fir;
            unsigned df;
            int fir_comp;
            unsigned frame_size_log2;
            unsigned index_bit_reversal;
            unsigned gain_comp_enabled;
            unsigned gain_comp[8];
            unsigned windowing_enabled;
            e_decimator_buffering_type buf_type;
            c_model :> fir;
            c_model :> debug_fir;
            c_model :> df;
            c_model :> fir_comp;
            c_model :> frame_size_log2;
            c_model :> index_bit_reversal;
            c_model :> gain_comp_enabled;
            for(unsigned i=0;i<8;i++)
                c_model:> gain_comp[i];
            c_model :> windowing_enabled;
            c_model :> buf_type;

            int output[8][COUNT<<MAX_FRAME_SIZE_LOG2];
            memset(second_stage_data, 0, sizeof(int)*16*8);
            memset(third_stage_data, 0, sizeof(int)*32*DF*8);//?
            memset(output, 0, sizeof(int)*(COUNT<<MAX_FRAME_SIZE_LOG2)*8);
            int val[8];


            for(unsigned c=0;c<(COUNT<<frame_size_log2);c++){
                for(unsigned r=0;r<df;r++){
                    for(unsigned p=0;p<4;p++){

                        int data[8];
                        for(unsigned i=0;i<8;i++){
                            data[i] = pseudo_random(x);
                            val[i] = filter(fir2_debug, second_stage_data[i], 16, data[i]);
                        }
                        for(unsigned i=0;i<4;i++){
                            c_4x_pdm_mic_0 <: data[i*2];
                            c_4x_pdm_mic_1 <: data[i*2+1];
                        }
                    }
                    for(unsigned i=0;i<8;i++)
                        val[i] = filter(debug_fir, third_stage_data[i], 32*df, val[i]);
                }

                //this is to accomotate for the channel interleaving
                unsigned reorder_channels[8] = {0, 2, 4, 6, 1, 3, 5, 7};

                if (c<(COUNT<<frame_size_log2)-2) {
                    for(unsigned m=0;m<8;m++){

                        int v = apply_fir_comp(val[reorder_channels[m]], fir_comp);
                        if(gain_comp_enabled)
                            v = apply_gain_comp(v, gain_comp[m]);

                        unsigned index = 0;
                        if(frame_size_log2)
                            index = zext(c+2, frame_size_log2);


                        if(windowing_enabled){
                            if(index>>(frame_size_log2-1))
                                index = (1<<frame_size_log2) -1- index;
                            int w = window[index];
                            v = apply_gain_comp(v, w);
                        }

                        output[m][c+2] = v;
                    }
                }
            }

            for(unsigned i=0;i<4*(3+generate_tail_output_counter(frame_size_log2, df));i++){
                c_4x_pdm_mic_0 <: 0;
                c_4x_pdm_mic_1 <: 0;
            }

            for(unsigned m=0;m<8;m++){
                for(unsigned c=0;c<COUNT<<frame_size_log2;c++){
                    c_model <: output[m][c];
                }
            }
            c_model <: 0;
        }
    }
}


void output(streaming chanend c_ds_output[2], chanend c_actual){

    int window[1<<(MAX_FRAME_SIZE_LOG2-1)];
    {
        unsigned x=0x9876543;
        for(unsigned i=0;i<(1<<(MAX_FRAME_SIZE_LOG2-1)); i++)
            window[i] = pseudo_random(x);
    }


    unsafe {
        while(1){
            //get the settings from the verifier

            int * unsafe fir;
            int * unsafe debug_fir;
            unsigned df;
            int fir_comp;
            unsigned frame_size_log2;
            unsigned index_bit_reversal;
            unsigned gain_comp_enabled;
            unsigned gain_comp[8];
            unsigned windowing_enabled;
            e_decimator_buffering_type buf_type;
            c_actual :> fir;
            c_actual :> debug_fir;
            c_actual :> df;
            c_actual :> fir_comp;
            c_actual :> frame_size_log2;
            c_actual :> index_bit_reversal;
            c_actual :> gain_comp_enabled;
            for(unsigned i=0;i<8;i++)
                c_actual:> gain_comp[i];
            c_actual :> windowing_enabled;
            c_actual :> buf_type;

            unsigned buffer;

            int output[8][COUNT<<MAX_FRAME_SIZE_LOG2];

            memset(data_0, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);
            memset(data_1, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);

            if(index_bit_reversal){
                unsafe {
                    decimator_config_common dcc = {frame_size_log2, 0, index_bit_reversal, 0, df, fir, gain_comp_enabled, fir_comp};

                    if(windowing_enabled)
                        dcc.windowing_function = window;

                    decimator_config dc[2] = {
                           {&dcc, data_0, {gain_comp[0], gain_comp[1], gain_comp[2], gain_comp[3]}, 4},
                           {&dcc, data_1, {gain_comp[4], gain_comp[5], gain_comp[6], gain_comp[7]}, 4}
                    };
                    decimator_configure(c_ds_output, 2, dc);
                }
               decimator_init_complex_frame(c_ds_output, 2, buffer, f_complex, buf_type);

               for(unsigned c=0;c<COUNT;c++){
                    frame_complex *  current = decimator_get_next_complex_frame(c_ds_output, 2, buffer, f_complex, 2);
                    for(unsigned f=0;f<(1<<frame_size_log2);f++){
                        unsigned index = (c<<frame_size_log2) + bitreverse(f, frame_size_log2);
                        for(unsigned m=0;m<4;m++){
                            output[2*m  ][index] = current->data[m][f].re;
                            output[2*m+1][index] = current->data[m][f].im;
                        }
                    }
               }
            } else {
                unsafe {
                    decimator_config_common dcc = {frame_size_log2, 0, index_bit_reversal, 0, df, fir, gain_comp_enabled, fir_comp};

                    if(windowing_enabled)
                        dcc.windowing_function = window;

                    decimator_config dc[2] = {
                           {&dcc, data_0, {gain_comp[0], gain_comp[1], gain_comp[2], gain_comp[3]}, 4},
                           {&dcc, data_1, {gain_comp[4], gain_comp[5], gain_comp[6], gain_comp[7]}, 4}
                    };
                    decimator_configure(c_ds_output, 2, dc);
                }
               decimator_init_audio_frame(c_ds_output, 2, buffer, audio, buf_type);

               for(unsigned c=0;c<COUNT;c++){
                    frame_audio *  current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);
                    for(unsigned f=0;f<(1<<frame_size_log2);f++){
                        for(unsigned m=0;m<8;m++){
                            output[m][(c<<frame_size_log2) + f] = current->data[m][f];
                        }
                    }
               }
           }
           for(unsigned m=0;m<8;m++){
               for(unsigned c=0;c<COUNT<<frame_size_log2;c++){
                   c_actual <: output[m][c];
               }
           }
           c_actual <: 0;
        }
    }
}

void send_settings(chanend  c_chan,
        const int * unsafe fir, int * unsafe debug_fir, unsigned df, int fir_comp,
        unsigned frame_size_log2, unsigned index_bit_reversal, unsigned  gain_comp_enabled,
        unsigned gain[8], unsigned windowing_enabled,
        e_decimator_buffering_type buf_type){
    unsafe{
        c_chan <: fir;
        c_chan <: debug_fir;
        c_chan <: df;
        c_chan <: fir_comp;
        c_chan <: frame_size_log2;
        c_chan <: index_bit_reversal;
        c_chan <: gain_comp_enabled;
        for(unsigned i=0;i<8;i++)
            c_chan <: gain[i];
        c_chan <: windowing_enabled;
        c_chan <: buf_type;

    }
}


void verifier(chanend c_model,
        chanend c_actual){
    unsafe{
        unsigned decimation_factor_lut[5] = {1*2, 2*2, 3*2, 4*2, 6*2};
        const int * unsafe decimation_fir_lut[5] = {
                g_third_stage_div_2_fir,
                g_third_stage_div_4_fir,
                g_third_stage_div_6_fir,
                g_third_stage_div_8_fir,
                g_third_stage_div_12_fir,
        };
        int * unsafe decimation_fir_debug_lut[5] = {
                fir3_div_2_debug,
                fir3_div_4_debug,
                fir3_div_6_debug,
                fir3_div_8_debug,
                fir3_div_12_debug,
        };

        unsigned fir_comp_lut[4] = {0, INT_MAX>>4, INT_MAX<<4, INT_MAX>>8};

        unsigned gain_comp[2][8] = {
                {INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX},
                {INT_MAX/2, INT_MAX/3, INT_MAX/4, INT_MAX/6, INT_MAX/7, INT_MAX/8, INT_MAX/9, INT_MAX/11}
        };


        //TODO dc offset elim
        //TODO channel count

        unsigned test = 0;
        for(unsigned frame_size_log2 = 0;frame_size_log2<=MAX_FRAME_SIZE_LOG2;frame_size_log2++){

            for(unsigned decimation_index = 0; decimation_index < 5;decimation_index++){
                const int * unsafe fir = decimation_fir_lut[decimation_index];
                int * unsafe debug_fir = decimation_fir_debug_lut[decimation_index];
                unsigned df = decimation_factor_lut[decimation_index];

                for(unsigned fir_comp_index=0; fir_comp_index<4;fir_comp_index++){
                    int fir_comp = fir_comp_lut[fir_comp_index];

                    for(unsigned index_bit_reversal=0;index_bit_reversal<2;index_bit_reversal++){

                        for(unsigned gain_comp_enabled = 0; gain_comp_enabled<2;gain_comp_enabled++){

                            for(unsigned gain_index=0;gain_index<2;gain_index++){

                                for(unsigned windowing_enabled=0;windowing_enabled<2; windowing_enabled++){

                                    for(e_decimator_buffering_type buf_type = 1; buf_type<2; buf_type++){
                                        if((frame_size_log2 == 0) && (buf_type == DECIMATOR_HALF_FRAME_OVERLAP))
                                            continue;
                                        send_settings(c_model, fir, debug_fir, df, fir_comp,
                                                frame_size_log2, index_bit_reversal, gain_comp_enabled,
                                                gain_comp[gain_index], windowing_enabled, buf_type);
                                        send_settings(c_actual, fir, debug_fir, df, fir_comp,
                                                frame_size_log2, index_bit_reversal, gain_comp_enabled,
                                                gain_comp[gain_index], windowing_enabled, buf_type);

                                        int max_diff = 0;

                                        for(unsigned m=0;m<8;m++){

                                            for(unsigned i=0;i<COUNT<<frame_size_log2;i++){
                                                int a, b;
                                                c_actual:> a;
                                                c_model :> b;
                                                int diff = a-b;
                                                if (diff<0) diff = -diff;
                                                if(diff>max_diff)
                                                    max_diff = diff;
                                            }
                                        }
                                        printf("%4d ", test++);
                                        printf("df: %2d ", df);
                                        printf("fir_comp: 0x%08x ", fir_comp);
                                        printf("frame_size_log2: %d ", frame_size_log2);
                                        printf("index_bit_reversal: %d ", index_bit_reversal);
                                        printf("windowing_enabled: %d ", windowing_enabled);
                                        printf("gain_comp_enabled: %d ", gain_comp_enabled);
                                        printf("e_decimator_buffering_type: %d ", buf_type);

                                        if(max_diff < 16)
                                            printf(" PASS\n");
                                        else{
                                            printf(" FAIL\n");
                                            _Exit(1);
                                        }

                                        c_actual:> int;
                                        c_model :> int;
                                    }
                                }
                            }
                        }
                    }
                }
            }
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
