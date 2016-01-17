// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <xs1.h>
#include <string.h>

#define DEBUG_UNIT DEBUG_MIC_ARRAY

#if DEBUG_MIC_ARRAY
#include "xassert.h"
#endif

void decimator_init_audio_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
        unsigned &buffer, frame_audio audio[], e_decimator_buffering_type buffering_type){
    memset(audio[0].metadata, 0, 2*sizeof(s_metadata));
    unsigned frames=1;

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
               c_from_decimator[i] <: (frame_audio * unsafe)audio[f].data[i*4];
            for(unsigned i=0;i<decimator_count;i++)
               c_from_decimator[i] <: (frame_audio * unsafe)&audio[f].metadata[i];
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
        unsigned &buffer, frame_audio * alias audio, unsigned buffer_count){
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
            c_from_decimator[i] <: (frame_audio * unsafe)audio[buffer].data[i*4];
         for(unsigned i=0;i<decimator_count;i++)
            c_from_decimator[i] <: (frame_audio * unsafe)&audio[buffer].metadata[i];
    }

    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

    unsigned index;
    if(buffer == 0)
        index = buffer_count-1;
    else
        index = buffer-1;

    buffer++;
    if(buffer == buffer_count)
        buffer = 0;
    return &audio[index];
}

void decimator_init_complex_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, frame_complex f_audio[], e_decimator_buffering_type buffering_type){
     memset(f_audio[0].metadata, 0, 2*sizeof(s_metadata));
     unsigned frames;

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
                c_from_decimator[i] <: (frame_complex * unsafe)f_audio[f].data[i*2];
             for(unsigned i=0;i<decimator_count;i++)
                c_from_decimator[i] <: (frame_complex * unsafe)&f_audio[f].metadata[i];
         }
     }
     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     buffer = frames;
}

frame_complex * alias decimator_get_next_complex_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, frame_complex * alias f_complex, unsigned buffer_count){
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
            c_from_decimator[i] <: (frame_complex * unsafe)f_complex[buffer].data[i*2];
         for(unsigned i=0;i<decimator_count;i++)
            c_from_decimator[i] <: (frame_complex * unsafe)&f_complex[buffer].metadata[i];
     }

     for(unsigned i=0;i<decimator_count;i++)
         schkct(c_from_decimator[i], 8);

     unsigned index;
     if(buffer == 0)
         index = buffer_count-1;
     else
         index = buffer-1;

     buffer++;
     if(buffer == buffer_count)
         buffer = 0;

     return &f_complex[index];
}

void decimator_configure(streaming chanend c_from_decimator[], unsigned decimator_count,
        decimator_config dc[]){

    for(unsigned i=0;i<decimator_count;i++)
        schkct(c_from_decimator[i], 8);

     for(unsigned i=0;i<decimator_count;i++)
         soutct(c_from_decimator[i], CONFIGURE_DECIMATOR);

     unsafe {
         for(unsigned i=0;i<decimator_count;i++)
             c_from_decimator[i] <: (decimator_config * unsafe)&dc[i];
     }
}

