// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include <platform.h>
#include "mic_array.h"
#include <xs1.h>
#include <xclib.h>
#include <stdlib.h>
#include <string.h>
#include "debug_print.h"
#include <stdio.h>

#define DF 12    //12 is the maximum I want to support
#define FRAME_COUNT 3

static int pseudo_random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return (int)x;
}

#pragma unsafe arrays
static unsafe void add_to_filter(int * unsafe data, const unsigned length,
        const int val, unsigned &n){
    data[n] = val;
    if ((n + 1) == length)
        n=0;
    else
        n=n+1;
}

#pragma unsafe arrays
static unsafe int filter(const int * unsafe coefs, int * unsafe data, const unsigned length,
        const int val, unsigned &n){

    long long y = 0;
    data[n] = val;
    for (unsigned i=0; i<length; i++)
        y += (long long)coefs[i] * (long long)data[((length - i) + n) % length];

    if ((n + 1) == length)
        n=0;
    else
        n=n+1;
    return y>>31;
}

#pragma unsafe arrays
int generate_tail_output_counter(unsigned fsl2, unsigned df, mic_array_decimator_buffering_t buf_type){
    if(buf_type == DECIMATOR_NO_FRAME_OVERLAP){
        if(fsl2==0)
            return 0;
        unsigned v=df*4;
        for(unsigned i=1;i<fsl2;i++)
            v = v*2+df*4;
        return v;
    } else {
        unsigned lut0[13] = { 0, 0, 0, 0, 1, 0, 2, 0, 3, 0, 0, 0, 4 };
        unsigned lut[5][5] = {
                {0, 0,  0,   0,    0},
                {0, 0,  0,   0,    0},
                {8*1, 8*2, 8*3, 8*4, 8*6},
                {12*2, 24*2, 36*2,  48*2,  72*2},
                {28*2, 56*2, 84*2, 112*2, 168*2},
        };
        return lut[fsl2][lut0[df]];
    }
}

static int apply_fir_comp(int val, int fir_comp){
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

static int apply_gain_comp(int val, int gain){
    long long v = (long long)val;
    v = v * (long long)gain;
    v=v>>31;
    return (int)v;
}

static unsigned bitreverse(unsigned i, unsigned bits){
    return (bitrev(i) >> (32-bits));
}

#pragma unsafe arrays
void model(streaming chanend c_4x_pdm_mic[4], unsigned channel_count, chanend c_model){
    int second_stage_data[16][16];
    int third_stage_data[16][32*DF];

    unsigned second_stage_n[16] = {0};
    unsigned third_stage_n[16] = {0};

    int window[1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1)];
    {
        unsigned x=0x9876543;
        for(unsigned i=0;i<(1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1)); i++)
            window[i] = pseudo_random(x);
    }

    unsigned x=0x1234;
    unsafe {
        while(1){

            c_model :> int;
            c_model <: 0;
            int r;
            c_model :> r;
            if(r)
                return;

            int * unsafe fir;
            int * unsafe debug_fir;
            unsigned df;
            int fir_comp;
            unsigned frame_size_log2;
            unsigned index_bit_reversal;
            unsigned gain_comp_enabled;
            unsigned gain_comp[16];
            unsigned windowing_enabled;
            mic_array_decimator_buffering_t buf_type;
            slave{
                c_model :> fir;
                c_model :> debug_fir;
                c_model :> df;
                c_model :> fir_comp;
                c_model :> frame_size_log2;
                c_model :> index_bit_reversal;
                c_model :> gain_comp_enabled;
                for(unsigned i=0;i<16;i++)
                    c_model:> gain_comp[i];
                c_model :> windowing_enabled;
                c_model :> buf_type;
            }
            int output[16][COUNT<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2];
            memset(second_stage_data, 0, sizeof(int)*16*16);
            memset(third_stage_data, 0, sizeof(int)*32*DF*16);
            memset(output, 0, sizeof(int)*(COUNT<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2)*16);
            memset(second_stage_n, 0, sizeof(unsigned)*16);
            memset(third_stage_n, 0, sizeof(unsigned)*16);
            int val[16];


            for(unsigned c=0;c<(COUNT<<frame_size_log2);c++){
                for(unsigned r=0;r<df-1;r++){
                    for(unsigned p=0;p<3;p++){

                        int data[16];
                        for(unsigned i=0;i<channel_count;i++){
                            data[i] = pseudo_random(x);
                            add_to_filter(second_stage_data[i], 16, data[i], second_stage_n[i]);
                        }
                        for(unsigned i=0;i<4;i++){
                            for(unsigned j=0;j<channel_count/4;j++){
                                c_4x_pdm_mic[j] <: data[i*(channel_count/4)+j];
                            }
                        }
                    }
                    {

                        int data[16];
                        for(unsigned i=0;i<channel_count;i++){
                            data[i] = pseudo_random(x);
                            val[i] = filter(fir2_debug, second_stage_data[i], 16, data[i], second_stage_n[i]);
                        }
                        for(unsigned i=0;i<4;i++){
                            for(unsigned j=0;j<channel_count/4;j++){
                                c_4x_pdm_mic[j] <: data[i*(channel_count/4)+j];
                            }
                        }
                    }
                    for(unsigned i=0;i<channel_count;i++)
                        add_to_filter(third_stage_data[i], 32*df, val[i], third_stage_n[i]);
                }
                {
                    for(unsigned p=0;p<3;p++){

                        int data[16];
                        for(unsigned i=0;i<channel_count;i++){
                            data[i] = pseudo_random(x);
                            add_to_filter(second_stage_data[i], 16, data[i], second_stage_n[i]);
                        }
                        for(unsigned i=0;i<4;i++){
                            for(unsigned j=0;j<channel_count/4;j++){
                                c_4x_pdm_mic[j] <: data[i*(channel_count/4)+j];
                            }
                        }
                    }
                    {

                        int data[16];
                        for(unsigned i=0;i<channel_count;i++){
                            data[i] = pseudo_random(x);
                            val[i] = filter(fir2_debug, second_stage_data[i], 16, data[i], second_stage_n[i]);
                        }
                        for(unsigned i=0;i<4;i++){
                            for(unsigned j=0;j<channel_count/4;j++){
                                c_4x_pdm_mic[j] <: data[i*(channel_count/4)+j];
                            }
                        }
                    }
                    for(unsigned i=0;i<channel_count;i++)
                        val[i] = filter(debug_fir, third_stage_data[i], 32*df, val[i], third_stage_n[i]);
                }

                unsigned reorder_channels[16];
                unsigned k=0;
                for(unsigned i=0;i<channel_count;i+=4){
                    for(unsigned j=0;j<4;j++){
                        reorder_channels[k++] =  i/4 + j*(channel_count/4);
                    }
                }

                if (c<(COUNT<<frame_size_log2)-2) {
                    for(unsigned m=0;m<channel_count;m++){


                        int v = apply_fir_comp(val[reorder_channels[m]], fir_comp);
                        if(gain_comp_enabled)
                            v = apply_gain_comp(v, gain_comp[m]);



                        unsigned index = 0;
                        if(frame_size_log2)
                            index = zext(c+2, frame_size_log2);

                        if(windowing_enabled){
                            if(buf_type == DECIMATOR_HALF_FRAME_OVERLAP){

                                if(!(index>>(frame_size_log2-1)))
                                    index += (1<<(frame_size_log2-1));

                                if(index>>(frame_size_log2-1))
                                    index = (1<<frame_size_log2) -1- index;

                                int w = window[index];
                                v = apply_gain_comp(v, w);
                            } else {
                                if(index>>(frame_size_log2-1))
                                    index = (1<<frame_size_log2) -1- index;
                                int w = window[index];
                                v = apply_gain_comp(v, w);
                            }
                        }

                       // printf("output[%d][%d]=%08x\n",m, c+2, v);
                        output[m][c+2] = v;
                    }
                }
            }

            for(unsigned i=0;i<4*(3+generate_tail_output_counter(frame_size_log2, df, buf_type));i++){
                for(unsigned j=0;j<channel_count/4;j++){
                    c_4x_pdm_mic[j] <: 0;
                }
            }


#define DEBUG_MODEL  0
#define DEBUG_OUTPUT 0

            for(unsigned c=0;c<COUNT<<frame_size_log2;c++){
                for(unsigned m=0;m<channel_count;m++){
                    c_model <: output[m][c];
#if DEBUG_MODEL

#if MIC_ARRAY_WORD_LENGTH_SHORT
                    printf("%08x ", output[m][c]>>16);
#else
                    printf("%08x ", output[m][c]);
#endif
#endif
                }
#if DEBUG_MODEL
                printf("\n");
#endif
            }
        }
    }
}

#pragma unsafe arrays
void output(streaming chanend c_ds_output[4], chanend c_actual, unsigned channel_count){

    mic_array_frame_time_domain  audio[FRAME_COUNT];
    mic_array_frame_fft_preprocessed f_complex[FRAME_COUNT];

    //FIXME this might cause weird crashes!! due to memory alignment
    int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
    int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
    int data_2[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
    int data_3[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};

    int window[1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1)];
    {
        unsigned x=0x9876543;
        for(unsigned i=0;i<(1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1)); i++)
            window[i] = pseudo_random(x);
    }

    unsafe {

        while(1){
            //get the settings from the verifier

            c_actual :> int;
            c_actual <: 0;
            int r;
            c_actual :> r;
            if(r)
                return;

            int * unsafe fir;
            int * unsafe debug_fir;
            unsigned df;
            int fir_comp;
            unsigned frame_size_log2;
            unsigned index_bit_reversal;
            unsigned gain_comp_enabled;
            unsigned gain_comp[16];
            unsigned windowing_enabled;
            mic_array_decimator_buffering_t buf_type;
            slave{
                c_actual :> fir;
                c_actual :> debug_fir;
                c_actual :> df;
                c_actual :> fir_comp;
                c_actual :> frame_size_log2;
                c_actual :> index_bit_reversal;
                c_actual :> gain_comp_enabled;
                for(unsigned i=0;i<16;i++)
                    c_actual:> gain_comp[i];
                c_actual :> windowing_enabled;
                c_actual :> buf_type;
            }
            unsigned buffer;

            int output[16][COUNT<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2];

            memset(data_0, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);
            memset(data_1, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);
            memset(data_2, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);
            memset(data_3, 0, sizeof(int)*4*THIRD_STAGE_COEFS_PER_STAGE*DF);

            memset(audio, 0, sizeof(mic_array_frame_time_domain)*FRAME_COUNT);
            memset(f_complex, 0, sizeof(mic_array_frame_fft_preprocessed)*FRAME_COUNT);


        unsigned frame_number = 0;
            if(index_bit_reversal){
                mic_array_decimator_conf_common_t dcc = {frame_size_log2, 0, index_bit_reversal, 0, df, fir,
                            gain_comp_enabled, fir_comp, buf_type, FRAME_COUNT};

                    if(windowing_enabled)
                        dcc.windowing_function = window;

                    mic_array_decimator_config_t dc[4] = {
                            {&dcc, data_0, {gain_comp[0], gain_comp[1], gain_comp[2], gain_comp[3]}, 4, 0},
                            {&dcc, data_1, {gain_comp[4], gain_comp[5], gain_comp[6], gain_comp[7]}, 4, 0},
                            {&dcc, data_2, {gain_comp[8], gain_comp[9], gain_comp[10], gain_comp[11]}, 4, 0},
                            {&dcc, data_3, {gain_comp[12], gain_comp[13], gain_comp[14], gain_comp[15]}, 4, 0}
                    };
                    mic_array_decimator_configure(c_ds_output, channel_count/4, dc);

                    mic_array_init_frequency_domain_frame(c_ds_output,  channel_count/4, buffer, f_complex, dc);


               if(buf_type==DECIMATOR_NO_FRAME_OVERLAP){
                   for(unsigned c=0;c<COUNT;c++){
                       mic_array_frame_fft_preprocessed *  current = mic_array_get_next_frequency_domain_frame(c_ds_output,  channel_count/4, buffer, f_complex, dc);

                       for(unsigned md=0;md < channel_count/4;md++){
                           if(current->metadata[md].frame_number != frame_number){
                               printf("error 1: got frame %d expected %d\n", current->metadata[md].frame_number, frame_number);
                           }
                       }
                       frame_number++;

                       for(unsigned f=0;f<(1<<frame_size_log2);f++){
                            unsigned ff = bitreverse(f, frame_size_log2);
                            unsigned index = (c<<frame_size_log2) + bitreverse(f, frame_size_log2);
                            for(unsigned m=0;m<channel_count/2;m++){
                                output[2*m  ][index] = current->data[m][f].re;
                                output[2*m+1][index] = current->data[m][f].im;
                            }
                        }
                   }
               } else {
                   for(unsigned c=0;c<2*COUNT;c++){
                       mic_array_frame_fft_preprocessed *  current = mic_array_get_next_frequency_domain_frame(c_ds_output,  channel_count/4, buffer, f_complex, dc);


                       for(unsigned md=0;md < channel_count/4;md++){
                           if(current->metadata[md].frame_number != frame_number){
                               printf("error 2: got frame %d expected %d\n", current->metadata[md].frame_number, frame_number);
                           }
                       }
                       frame_number++;


                       if(c > 0){
                            for(unsigned f=0;f<(1<<(frame_size_log2-1));f++){
                                for(unsigned m=0;m<channel_count/2;m++){
                                    //TODO compare to the previous buffer - if not windowing
                                    //output[2*m  ][index] = current->data[m][f].re;
                                    //output[2*m+1][index] = current->data[m][f].im;
                                }
                            }
                        }
                        for(unsigned f=(1<<(frame_size_log2-1));f<(1<<frame_size_log2);f++){
                            unsigned ff = bitreverse(f, frame_size_log2);
                            unsigned index = (c<<(frame_size_log2-1)) + f - (1<<(frame_size_log2-1));
                            for(unsigned m=0;m<channel_count/2;m++){
                                output[2*m  ][index] = current->data[m][ff].re;
                                output[2*m+1][index] = current->data[m][ff].im;
                            }
                        }

                   }
               }
            } else {
                mic_array_decimator_conf_common_t dcc = {
                            frame_size_log2, 0, index_bit_reversal, 0, df, fir, gain_comp_enabled, fir_comp, buf_type, FRAME_COUNT};

                    if(windowing_enabled)
                        dcc.windowing_function = window;

                    mic_array_decimator_config_t dc[4] = {
                            {&dcc, data_0, {gain_comp[0], gain_comp[1], gain_comp[2], gain_comp[3]}, 4, 0},
                            {&dcc, data_1, {gain_comp[4], gain_comp[5], gain_comp[6], gain_comp[7]}, 4, 0},
                            {&dcc, data_2, {gain_comp[8], gain_comp[9], gain_comp[10], gain_comp[11]}, 4, 0},
                            {&dcc, data_3, {gain_comp[12], gain_comp[13], gain_comp[14], gain_comp[15]}, 4, 0}
                    };
                    mic_array_decimator_configure(c_ds_output, channel_count/4, dc);

                    mic_array_init_time_domain_frame(c_ds_output, channel_count/4, buffer, audio, dc);

               if(buf_type==DECIMATOR_NO_FRAME_OVERLAP){
                   for(unsigned c=0;c<COUNT;c++){
                       mic_array_frame_time_domain *  current = mic_array_get_next_time_domain_frame(c_ds_output, channel_count/4, buffer, audio, dc);


                       for(unsigned md=0;md < channel_count/4;md++){

                           if(current->metadata[md].frame_number != frame_number){
                               printf("error 3: got frame %d expected %d\n", current->metadata[md].frame_number, frame_number);
                           }
                       }
                       frame_number++;

                       for(unsigned f=0;f<(1<<frame_size_log2);f++){
                            for(unsigned m=0;m<channel_count;m++){
                                output[m][(c<<frame_size_log2) + f] = current->data[m][f];
                            }
                        }
                   }
               } else {
                   for(unsigned c=0;c<2*COUNT;c++){
                       mic_array_frame_time_domain *  current = mic_array_get_next_time_domain_frame(c_ds_output, channel_count/4, buffer, audio, dc);


                       for(unsigned md=0;md < channel_count/4;md++){
                           if(current->metadata[md].frame_number != frame_number){
                               printf("error 4: got frame %d expected %d\n", current->metadata[md].frame_number, frame_number);
                           }
                       }
                       frame_number++;

                       if(c > 0){
                            for(unsigned f=0;f<(1<<(frame_size_log2-1));f++){
                                unsigned index = (c<<(frame_size_log2-1)) + f - (1<<(frame_size_log2-1));
                                for(unsigned m=0;m<channel_count;m++){
                                    //TODO compare to the previous buffer - if not windowing
                                    //output[m][(c<<frame_size_log2) + f] = current->data[m][f];
                                }
                            }
                        }
                        for(unsigned f=(1<<(frame_size_log2-1));f<(1<<frame_size_log2);f++){
                            unsigned index = (c<<(frame_size_log2-1)) + f - (1<<(frame_size_log2-1));
                            for(unsigned m=0;m<channel_count;m++){
                                output[m][index] = current->data[m][f];
                            }
                        }
                   }
               }
           }

           for(unsigned c=0;c<COUNT<<frame_size_log2;c++){
               for(unsigned m=0;m<channel_count;m++){
                   c_actual <: output[m][c];
#if DEBUG_OUTPUT
#if MIC_ARRAY_WORD_LENGTH_SHORT
                   printf("%08x ", output[m][c]>>16);
#else
                   printf("%08x ", output[m][c]);
#endif
#endif
               }
#if DEBUG_OUTPUT
               printf("\n");
#endif
           }
        }
    }
}

#pragma unsafe arrays
static void send_settings(chanend  c_chan,
        const int * unsafe fir, const int * unsafe debug_fir, unsigned df, int fir_comp,
        unsigned frame_size_log2, unsigned index_bit_reversal, unsigned  gain_comp_enabled,
        unsigned gain[16], unsigned windowing_enabled,
        mic_array_decimator_buffering_t buf_type){
    unsafe{
        master {
            c_chan <: fir;
            c_chan <: debug_fir;
            c_chan <: df;
            c_chan <: fir_comp;
            c_chan <: frame_size_log2;
            c_chan <: index_bit_reversal;
            c_chan <: gain_comp_enabled;
            for(unsigned i=0;i<16;i++)
                c_chan <: gain[i];
            c_chan <: windowing_enabled;
            c_chan <: buf_type;
        }

    }
}

#pragma unsafe arrays
void verifier(chanend c_model, chanend c_actual, unsigned channel_count){
    unsafe{
        unsigned decimation_factor_lut[5] = {1*2, 2*2, 3*2, 4*2, 6*2};

        const int * unsafe decimation_fir_lut[5] = {
                g_third_stage_div_2_fir,
                g_third_stage_div_4_fir,
                g_third_stage_div_6_fir,
                g_third_stage_div_8_fir,
                g_third_stage_div_12_fir,
        };
        const int * unsafe decimation_fir_debug_lut[5] = {
                fir3_div_2_debug,
                fir3_div_4_debug,
                fir3_div_6_debug,
                fir3_div_8_debug,
                fir3_div_12_debug,
        };

        unsigned fir_comp_lut[4] = {0, INT_MAX>>4, INT_MAX<<4, INT_MAX>>8};

        unsigned gain_comp[2][16] = { { INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX,
            INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX, INT_MAX,
            INT_MAX, INT_MAX }, { INT_MAX / 2, INT_MAX / 3, INT_MAX / 4, INT_MAX / 6,
            INT_MAX / 7, INT_MAX / 8, INT_MAX / 9, INT_MAX / 11,
            INT_MAX / 12, INT_MAX / 13, INT_MAX / 14, INT_MAX / 16, INT_MAX / 17, INT_MAX
            / 18, INT_MAX / 19, INT_MAX / 111, } };

        unsigned test = 0;

        for(unsigned frame_size_log2 = 0;frame_size_log2<=MIC_ARRAY_MAX_FRAME_SIZE_LOG2;frame_size_log2++){

            for(unsigned decimation_index = 0; decimation_index < 5;decimation_index++){
                const int * unsafe fir = decimation_fir_lut[decimation_index];
                const int * unsafe debug_fir = decimation_fir_debug_lut[decimation_index];
                unsigned df = decimation_factor_lut[decimation_index];

                for(unsigned fir_comp_index=0; fir_comp_index<4;fir_comp_index++){
                    int fir_comp = fir_comp_lut[fir_comp_index];

                    for(unsigned index_bit_reversal=0;index_bit_reversal<2;index_bit_reversal++){

                        for(unsigned gain_comp_enabled = 0; gain_comp_enabled<2;gain_comp_enabled++){

                            for(unsigned gain_index=0;gain_index<2;gain_index++){

                                for(unsigned windowing_enabled=0;windowing_enabled<2; windowing_enabled++){

                                    for(mic_array_decimator_buffering_t buf_type = 0; buf_type<2; buf_type++){
                                        if((frame_size_log2 == 0) && (buf_type == DECIMATOR_HALF_FRAME_OVERLAP))
                                            continue;

                                        c_actual <: 0;
                                        c_model  <: 0;
                                        c_actual:> int;
                                        c_model :> int;
                                        c_actual <: 0;
                                        c_model  <: 0;

                                        send_settings(c_model, fir, debug_fir, df, fir_comp,
                                                frame_size_log2, index_bit_reversal, gain_comp_enabled,
                                                gain_comp[gain_index], windowing_enabled, buf_type);
                                        send_settings(c_actual, fir, debug_fir, df, fir_comp,
                                                frame_size_log2, index_bit_reversal, gain_comp_enabled,
                                                gain_comp[gain_index], windowing_enabled, buf_type);

                                        int max_diff = 0;
                                        for(unsigned m=0;m<channel_count;m++){
                                            for(unsigned i=0;i<COUNT<<frame_size_log2;i++){
                                                int a, b;
                                                c_actual:> a;
                                                c_model :> b;
                                               // printf("%d %d\n", a, b);
#if MIC_ARRAY_WORD_LENGTH_SHORT
                                                b = b >>16;
#endif

                                                int diff = a-b;
                                                if (diff<0) diff = -diff;
                                                if(diff>max_diff)
                                                    max_diff = diff;
                                            }
                                        }

                                        if(max_diff < 16){
                                            test++;
                                        } else{
                                            printf("%4d ", test++);
                                            printf("df: %2d ", df);
                                            printf("fir_comp: 0x%08x ", fir_comp);
                                            printf("frame_size_log2: %d ", frame_size_log2);
                                            printf("index_bit_reversal: %d ", index_bit_reversal);
                                            printf("windowing_enabled: %d ", windowing_enabled);
                                            printf("gain_comp_enabled: %d ", gain_comp_enabled);
                                            printf("mic_array_decimator_buffering_t: %d ", buf_type);
                                            printf(" FAIL\n");
                                            delay_milliseconds(50);
                                            _Exit(1);

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

    c_actual <: 0;
    c_model  <: 0;
    c_actual:> int;
    c_model :> int;
    c_actual <: 1;
    c_model  <: 1;

    debug_printf("Success: %d channels supported\n", channel_count);
}

void channel_count_test(unsigned counts[], unsigned n){
    streaming chan c_4x_pdm_mic[4];
    streaming chan c_ds_output[4];
    chan c_model, c_actual;
    par {
        {
            for(unsigned c=0; c<n;c++){
                unsigned count=counts[c];
                par{
                    model(c_4x_pdm_mic, count, c_model);
                    output(c_ds_output, c_actual, count);
                    verifier(c_model, c_actual, count);
                }
            }
            if(counts[n-1] == 16){
                debug_printf("All done\n");
                _Exit(0);
            }
        }
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[2], c_ds_output[2], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[3], c_ds_output[3], MIC_ARRAY_NO_INTERNAL_CHANS);
        while(1);
     }
}

int main(){
    par{
        on tile[0]:{
            unsigned counts[2]= {4, 16};
            channel_count_test(counts, 2);
        }
        on tile[1]:{
            unsigned counts[2]= {8, 12};
            channel_count_test(counts, 2);
        }
    }
    return 0;
}
