// Copyright (c) 2015-2019, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <xs1.h>
#include <string.h>

#define XASSERT_UNIT DEBUG_MIC_ARRAY

#define DEBUG_UNIT MIC_ARRAY
#ifndef DEBUG_PRINT_ENABLE_MIC_ARRAY
    #define DEBUG_PRINT_ENABLE_MIC_ARRAY 0
#endif
#include "debug_print.h"

#if DEBUG_MIC_ARRAY
#include "xassert.h"
#endif

void mic_array_init_far_end_channels(mic_array_internal_audio_channels ch[4],
        streaming chanend ?a, streaming chanend ?b,
        streaming chanend ?c, streaming chanend ?d) {
    unsafe {
        ch[0] = isnull(a) ? 0 : (unsigned)a;
        ch[1] = isnull(b) ? 0 : (unsigned)b;
        ch[2] = isnull(c) ? 0 : (unsigned)c;
        ch[3] = isnull(d) ? 0 : (unsigned)d;
    }
}

int mic_array_send_sample(streaming chanend c_to_decimator, int sample){
    select {
        case c_to_decimator :> int:{
            c_to_decimator <: sample;
            return 0;
        }
        default:
            return 1;
    }
}

int mic_array_recv_samples(streaming chanend c_from_decimator, int &ch_a, int &ch_b) {
    select {
        case c_from_decimator :> ch_a:
            c_from_decimator :> ch_b;
            return 0;
        default:
            return 1;
    }
}

void mic_array_init_time_domain_frame(
        streaming chanend c_from_decimator[], unsigned decimator_count,
        unsigned &buffer, mic_array_frame_time_domain audio[],
        mic_array_decimator_config_t dc[]){

    unsigned frames=1;
    mic_array_decimator_buffering_t buffering_type;
    unsafe {buffering_type = dc[0].dcc->buffering_type;}

    if (buffering_type == DECIMATOR_NO_FRAME_OVERLAP){
        frames = 1;
    } else if (buffering_type == DECIMATOR_HALF_FRAME_OVERLAP){
        frames = 2;
    } else {
        //fail
#if DEBUG_MIC_ARRAY
        fail("Invalid buffering selected for: buffering_type");
#else
         __builtin_unreachable();
#endif
     }

   memset(audio, 0, sizeof(mic_array_frame_time_domain)*frames);

   for(unsigned i=0;i<decimator_count;i++)
        c_from_decimator[i] <: frames;
   for(unsigned f=0;f<frames;f++){
        unsafe {
            for(unsigned i=0;i<decimator_count;i++){
#if MIC_ARRAY_WORD_LENGTH_SHORT
                c_from_decimator[i] <: (int16_t * unsafe)(audio[f].data[i*4]);
#else
               c_from_decimator[i] <: (int32_t * unsafe)(audio[f].data[i*4]);
#endif
            }
            for(unsigned i=0;i<decimator_count;i++)
               c_from_decimator[i] <: (mic_array_metadata_t * unsafe)&audio[f].metadata[i];
        }
    }
    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

    buffer = frames;
}
#if DEBUG_MIC_ARRAY
static void check_timing(streaming chanend c_from_decimator){
    unsigned char val;
        #pragma ordered
        select {
            //Note: only checking decimator 0 is fine as if one fails they all fail
            case sinct_byref(c_from_decimator, val):{
                fail("Timing not met: decimators not serviced in time");
                break;
            }
            default:break;
        }
}
#endif

#define EXCHANGE_BUFFERS 0
#define CONFIGURE_DECIMATOR 1
mic_array_frame_time_domain * alias mic_array_get_next_time_domain_frame(
         streaming chanend c_from_decimator[], unsigned decimator_count,
        unsigned &buffer, mic_array_frame_time_domain * alias audio, mic_array_decimator_config_t dc[]){
#if DEBUG_MIC_ARRAY
    check_timing(c_from_decimator[0]);
#endif

     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     for(unsigned i=0;i<decimator_count;i++)
         soutct(c_from_decimator[i], EXCHANGE_BUFFERS);

    unsafe {
         for(unsigned i=0;i<decimator_count;i++){
#if MIC_ARRAY_WORD_LENGTH_SHORT
            c_from_decimator[i] <: (int16_t * unsafe)(audio[buffer].data[i*4]);
#else
            c_from_decimator[i] <: (int32_t * unsafe)(audio[buffer].data[i*4]);
#endif
         }
         for(unsigned i=0;i<decimator_count;i++)
            c_from_decimator[i] <: (mic_array_metadata_t * unsafe)&audio[buffer].metadata[i];
    }

    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

    unsigned index;
    unsigned buffer_count;
    mic_array_decimator_buffering_t buffering_type;
    unsafe {
        buffering_type = dc[0].dcc->buffering_type;
        buffer_count = dc[0].dcc->number_of_frame_buffers;
    }
    if(buffering_type == DECIMATOR_NO_FRAME_OVERLAP)
        index = buffer + buffer_count - 1;
    else
        index = buffer + buffer_count - 2;

    if(index >= buffer_count)
        index-=buffer_count;

    buffer++;
    if(buffer == buffer_count)
        buffer = 0;
    return &audio[index];
}

void mic_array_init_frequency_domain_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, mic_array_frame_fft_preprocessed f_fft_preprocessed[], mic_array_decimator_config_t dc[]){

     unsigned frames;
     mic_array_decimator_buffering_t buffering_type;
     unsafe {buffering_type = dc[0].dcc->buffering_type;}

     if (buffering_type == DECIMATOR_NO_FRAME_OVERLAP){
         frames = 1;
     } else if (buffering_type == DECIMATOR_HALF_FRAME_OVERLAP){
         frames = 2;
     } else {
         //fail
#if DEBUG_MIC_ARRAY
         fail("Invalid buffering selected for: buffering_type");
#else
         __builtin_unreachable();
#endif
     }

     memset(f_fft_preprocessed, 0, sizeof(mic_array_frame_fft_preprocessed)*frames);

     for(unsigned i=0;i<decimator_count;i++)
         c_from_decimator[i] <: frames;

     for(unsigned f=0;f<frames;f++){
         unsafe {
             for(unsigned i=0;i<decimator_count;i++)
                c_from_decimator[i] <: (mic_array_complex_t * unsafe)(f_fft_preprocessed[f].data[i*2]);
             for(unsigned i=0;i<decimator_count;i++)
                c_from_decimator[i] <: (mic_array_metadata_t * unsafe)&f_fft_preprocessed[f].metadata[i];
         }
     }
     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     buffer = frames;
}

mic_array_frame_fft_preprocessed * alias mic_array_get_next_frequency_domain_frame(
        streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, mic_array_frame_fft_preprocessed * alias f_fft_preprocessed,
     mic_array_decimator_config_t dc[]){
#if DEBUG_MIC_ARRAY
    check_timing(c_from_decimator[0]);
#endif

     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     for(unsigned i=0;i<decimator_count;i++)
         soutct(c_from_decimator[i], EXCHANGE_BUFFERS);
     unsafe {
         for(unsigned i=0;i<decimator_count;i++)
            c_from_decimator[i] <: (mic_array_complex_t * unsafe)(f_fft_preprocessed[buffer].data[i*2]);
         for(unsigned i=0;i<decimator_count;i++)
            c_from_decimator[i] <: (mic_array_metadata_t * unsafe)&f_fft_preprocessed[buffer].metadata[i];
     }

     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     unsigned index;
     unsigned buffer_count;
     mic_array_decimator_buffering_t buffering_type;
     unsafe {
         buffering_type = dc[0].dcc->buffering_type;
         buffer_count = dc[0].dcc->number_of_frame_buffers;
     }
     if(buffering_type == DECIMATOR_NO_FRAME_OVERLAP)
         index = buffer + buffer_count - 1;
     else
         index = buffer + buffer_count - 2;

     if(index >= buffer_count)
         index-=buffer_count;

     buffer++;
     if(buffer == buffer_count)
         buffer = 0;

     return &f_fft_preprocessed[index];
}

void mic_array_decimator_configure(
        streaming chanend c_from_decimator[],
        unsigned decimator_count,
        mic_array_decimator_config_t dc[]){

     //TODO check the frame_size_log_2 is in bounds
    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

     for(unsigned i=0;i<decimator_count;i++)
         soutct(c_from_decimator[i], CONFIGURE_DECIMATOR);

     unsafe {
         for(unsigned i=0;i<decimator_count;i++)
             c_from_decimator[i] <: (mic_array_decimator_config_t * unsafe)&dc[i];
     }
}

