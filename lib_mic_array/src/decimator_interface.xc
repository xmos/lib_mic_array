#include "frame.h"
#include "mic_array.h"
#include <xs1.h>

#define DEBUG_UNIT DEBUG_MIC_ARRAY

#include "xassert.h"

void decimator_init_audio_frame(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
        unsigned &buffer, frame_audio audio[]){
    unsafe {
        c_ds_output_0 <: (frame_audio * unsafe)audio[0].data[0];
        c_ds_output_1 <: (frame_audio * unsafe)audio[0].data[4];
    }
    buffer = 1;
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
    }
    buffer = 1-buffer;
    return &audio[buffer];
}

void decimator_init_complex_frame(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1,
     unsigned &buffer, frame_complex f_audio[]){
 unsafe {
     c_ds_output_0 <: (frame_complex * unsafe)f_audio[0].data[0];
     c_ds_output_1 <: (frame_complex * unsafe)f_audio[0].data[2];
 }
 buffer = 1;
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

