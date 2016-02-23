// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <xs1.h>
#include <string.h>

#define DEBUG_UNIT DEBUG_MIC_ARRAY

#if DEBUG_MIC_ARRAY
#include "xassert.h"
#endif

void decimator_init_audio_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
        unsigned &buffer, frame_audio audio[], decimator_config_common &dcc){
   // memset(audio[0].metadata, 0, dcc.number_of_frame_buffers*sizeof(s_metadata));
    unsigned frames=1;
    e_decimator_buffering_type buffering_type = dcc.buffering_type;

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
               c_from_decimator[i] <: (s_metadata * unsafe)&audio[f].metadata[i];
        }
    }
    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

    buffer = frames;
}

#define EXCHANGE_BUFFERS 0
#define CONFIGURE_DECIMATOR 1

 frame_audio * alias decimator_get_next_audio_frame(
         streaming chanend c_from_decimator[], unsigned decimator_count,
        unsigned &buffer, frame_audio * alias audio, decimator_config_common &dcc){
#if DEBUG_MIC_ARRAY
     #pragma ordered
     select {
         case c_from_decimator[int i] :> int:{
             fail("Timing not met: decimators not serviced in time");
             break;
         }
         default:break;
     }
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
            c_from_decimator[i] <: (s_metadata * unsafe)&audio[buffer].metadata[i];
    }

    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

    unsigned index;
    unsigned buffer_count = dcc.number_of_frame_buffers;

    e_decimator_buffering_type buffering_type = dcc.buffering_type;
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

void decimator_init_complex_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, frame_complex f_audio[], decimator_config_common &dcc){
    // memset(f_audio[0].metadata, 0, dcc.number_of_frame_buffers*sizeof(s_metadata));
     unsigned frames;
     e_decimator_buffering_type buffering_type = dcc.buffering_type;

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
     for(unsigned i=0;i<decimator_count;i++)
         c_from_decimator[i] <: frames;

     for(unsigned f=0;f<frames;f++){
         unsafe {
             for(unsigned i=0;i<decimator_count;i++)
                c_from_decimator[i] <: (complex * unsafe)(f_audio[f].data[i*2]);
             for(unsigned i=0;i<decimator_count;i++)
                c_from_decimator[i] <: (s_metadata * unsafe)&f_audio[f].metadata[i];
         }
     }
     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     buffer = frames;
}

frame_complex * alias decimator_get_next_complex_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, frame_complex * alias f_complex, decimator_config_common &dcc){
#if DEBUG_MIC_ARRAY
     #pragma ordered
     select {
         case c_from_decimator[int i] :> int:{
             fail("Timing not met: decimators not serviced in time");
             break;
         }
         default:break;
     }
#endif

     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     for(unsigned i=0;i<decimator_count;i++)
         soutct(c_from_decimator[i], EXCHANGE_BUFFERS);
     unsafe {
         for(unsigned i=0;i<decimator_count;i++)
            c_from_decimator[i] <: (complex * unsafe)(f_complex[buffer].data[i*2]);
         for(unsigned i=0;i<decimator_count;i++)
            c_from_decimator[i] <: (s_metadata * unsafe)&f_complex[buffer].metadata[i];
     }

     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     unsigned index;
     unsigned buffer_count = dcc.number_of_frame_buffers;
     e_decimator_buffering_type buffering_type = dcc.buffering_type;
     if(buffering_type == DECIMATOR_NO_FRAME_OVERLAP)
         index = buffer + buffer_count - 1;
     else
         index = buffer + buffer_count - 2;

     if(index >= buffer_count)
         index-=buffer_count;

     buffer++;
     if(buffer == buffer_count)
         buffer = 0;

     return &f_complex[index];
}

void decimator_configure(streaming chanend c_from_decimator[], unsigned decimator_count,
        decimator_config dc[]){


     //TODO check the frame_size_log_2 is in bounds
    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

     for(unsigned i=0;i<decimator_count;i++)
         soutct(c_from_decimator[i], CONFIGURE_DECIMATOR);

     unsafe {
         for(unsigned i=0;i<decimator_count;i++)
             c_from_decimator[i] <: (decimator_config * unsafe)&dc[i];
     }
}

