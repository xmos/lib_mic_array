// Copyright (c) 2015, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <xs1.h>
#include <string.h>

#define DEBUG_UNIT DEBUG_MIC_ARRAY

unsigned g_cic_max = (1<<30);

#if DEBUG_MIC_ARRAY
#include "xassert.h"
#endif

void decimator_init_audio_frame(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
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
    c_ds_output_0 <: frames;
    c_ds_output_1 <: frames;
    for(unsigned i=0;i<frames;i++){
        unsafe {
            c_ds_output_0 <: (frame_audio * unsafe)audio[i].data[0];
            c_ds_output_1 <: (frame_audio * unsafe)audio[i].data[4];
            c_ds_output_0 <: (frame_audio * unsafe)&audio[i].metadata[0];
            c_ds_output_1 <: (frame_audio * unsafe)&audio[i].metadata[1];
        }
    }
    buffer = frames;
}

#define EXCHANGE_BUFFERS 0
#define CONFIGURE_DECIMATOR 1


 frame_audio * alias decimator_get_next_audio_frame(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
        unsigned &buffer, frame_audio * alias audio){
#if DEBUG_MIC_ARRAY
     #pragma ordered
     select {
         case c_ds_output_0:> int:{
             fail("Timing not met: decimators not serviced in time");
             break;
         }
         case c_ds_output_1:> int:{
             fail("Timing not met: decimators not serviced in time");
             break;
         }
         default:break;
     }
#endif
    schkct(c_ds_output_0, 8);
    schkct(c_ds_output_1, 8);
    soutct(c_ds_output_0, EXCHANGE_BUFFERS);
    soutct(c_ds_output_1, EXCHANGE_BUFFERS);
    unsafe {
        c_ds_output_0 <: (int * unsafe)audio[buffer].data[0];
        c_ds_output_1 <: (int * unsafe)audio[buffer].data[4];
        c_ds_output_0 <: (int * unsafe)&audio[buffer].metadata[0];
        c_ds_output_1 <: (int * unsafe)&audio[buffer].metadata[1];
    }
    buffer = 1-buffer;
    return &audio[buffer];
}

void decimator_init_complex_frame(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
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

     c_ds_output_0 <: frames;
     c_ds_output_1 <: frames;
     for(unsigned i=0;i<frames;i++){
         unsafe {
             c_ds_output_0 <: (frame_complex * unsafe)f_audio[i].data[0];
             c_ds_output_1 <: (frame_complex * unsafe)f_audio[i].data[2];
             c_ds_output_0 <: (frame_complex * unsafe)&f_audio[i].metadata[0];
             c_ds_output_1 <: (frame_complex * unsafe)&f_audio[i].metadata[1];
         }
     }
     buffer = frames;
}

frame_complex * alias decimator_get_next_complex_frame(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
     unsigned &buffer, frame_complex * alias f_complex){
#if DEBUG_MIC_ARRAY
     #pragma ordered
     select {
         case c_ds_output_0:> int:{
             fail("Timing not met: decimators not serviced in time");
             break;
         }
         case c_ds_output_1:> int:{
             fail("Timing not met: decimators not serviced in time");
             break;
         }
         default:break;
     }
#endif
     schkct(c_ds_output_0, 8);
     schkct(c_ds_output_1, 8);
     soutct(c_ds_output_0, EXCHANGE_BUFFERS);
     soutct(c_ds_output_1, EXCHANGE_BUFFERS);
     unsafe {
         c_ds_output_0 <: (int * unsafe)f_complex[buffer].data[0];
         c_ds_output_1 <: (int * unsafe)f_complex[buffer].data[2];
         c_ds_output_0 <: (int * unsafe)&f_complex[buffer].metadata[0];
         c_ds_output_1 <: (int * unsafe)&f_complex[buffer].metadata[1];
     }
     buffer = 1-buffer;
     return &f_complex[buffer];
}

void decimator_configure(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
        decimator_config &dc0, decimator_config &dc1){
     schkct(c_ds_output_0, 8);
     schkct(c_ds_output_1, 8);

     soutct(c_ds_output_0, CONFIGURE_DECIMATOR);
     soutct(c_ds_output_1, CONFIGURE_DECIMATOR);

     unsafe {
         c_ds_output_0 <: (decimator_config * unsafe)&dc0;
         c_ds_output_1 <: (decimator_config * unsafe)&dc1;
     }
}

