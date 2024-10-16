// Copyright 2022-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <iostream>
#include <fstream>
#include <cstdio>
#include <cstring>

#include <print.h>
#include <string.h>

#include <xcore/channel.h>
#include <xcore/hwtimer.h>
#include <xcore/channel_streaming.h>

extern "C" {
#include "xscope.h"
}

#include "mic_array.h"

#include "app.h"

#ifndef CHAN_COUNT
# error CHAN_COUNT must be defined.
#endif
#ifndef SAMPLES_PER_FRAME
# error SAMPLES_PER_FRAME must be defined.
#endif
#ifndef USE_ISR
# error USE_ISR must be defined.
#endif 

 
// We'll be using a fairly standard mic array setup here, with one big 
// exception. Instead of feeding the PDM rx service with a port, we're going
// to feed it from a streaming channel. Under the surface it is just using an
// IN instruction on a resource. As long as it's given a 32-bit word, it
// doesn't particularly care what the resource is.
// Since we're not using a port, we also don't need to worry about setting up
// clocks or any of that silliness
using TMicArray = mic_array::prefab::BasicMicArray<CHAN_COUNT, SAMPLES_PER_FRAME, 
                                                    false, CHAN_COUNT>;

TMicArray mics;


void app_dec_task(
    chanend_t c_frames_out) //non-streaming
{
  mics.Init();
  mics.SetOutputChannel(c_frames_out);
  mics.ThreadEntry();
}

void app_pdm_rx_isr_setup(
    chanend_t c_from_host)
{
  mics.SetPort((port_t)c_from_host);
  
  mics.InstallPdmRxISR();
  mics.UnmaskPdmRxISR();
}


void app_pdm_task(chanend_t sc_mics)
{
  // We're just going to pretend that the streaming chanend is a port.
  mics.SetPort((port_t)sc_mics);

  // no need to start any clocks
  mics.PdmRxThreadEntry();
}


// Sometimes xscope doesn't keep up causing backpressure so add a FIFO to decouple this, at least up to 8 frames.
// We can buffer up to 8 chars in a same tile chanend.
const unsigned fifo_entries = 8;
typedef int32_t ma_frame_t[CHAN_COUNT][SAMPLES_PER_FRAME];
ma_frame_t frame_fifo[fifo_entries];


void app_output_task(chanend_t c_frames_in, chanend_t c_fifo)
{
  // Before listening for any frames, use the META_OUT xscope probe to report
  // our configuration to the host. This will help make sure the right version
  // of this application is being used.
  xscope_int(META_OUT, CHAN_COUNT);
  xscope_int(META_OUT, 256); // S1_TAP_COUNT
  xscope_int(META_OUT, 32); // S1_DEC_FACTOR
  xscope_int(META_OUT, STAGE2_TAP_COUNT);
  xscope_int(META_OUT, STAGE2_DEC_FACTOR);
  xscope_int(META_OUT, SAMPLES_PER_FRAME);
  xscope_int(META_OUT, USE_ISR); // Using interrupt


  // receive the output of the mic array and send it to the host via a fifo to decouple the backpressure from xscope
  int32_t frame[CHAN_COUNT][SAMPLES_PER_FRAME];
  uint8_t fifo_idx = 0;

  while(1){
    ma_frame_rx(&frame[0][0], c_frames_in, CHAN_COUNT, SAMPLES_PER_FRAME);
    memcpy(frame_fifo[fifo_idx], &frame[0][0], sizeof(ma_frame_t));

    int t0 = get_reference_time();
    chanend_out_byte(c_fifo, fifo_idx++);
    int t1 = get_reference_time();
    if(t1 - t0 > 10){
        printstrln("ERROR - Timing fail");
    }
    if(fifo_idx == fifo_entries){
        fifo_idx = 0;
    }
  }
}

void app_fifo_to_xscope_task(chanend_t c_fifo)
{
    while(1){
        uint8_t idx = chanend_in_byte(c_fifo);
        ma_frame_t *ptr = &frame_fifo[idx];

        // Send it to host sample by sample rather than channel by channel
        for(int smp = 0; smp < SAMPLES_PER_FRAME; smp++) {
          for(int ch = 0; ch < CHAN_COUNT; ch++){
            xscope_int(DATA_OUT, (*ptr)[ch][smp]);
          }
        }
    }
}



void app_print_filters()
{
  printf("stage1_coef = [\n");
  for(int a = 0; a < 32; a++){
    printf("0x%08X, 0x%08X, 0x%08X, 0x%08X, \n",
      (unsigned) stage1_coef[a*4+0], (unsigned) stage1_coef[a*4+1],
      (unsigned) stage1_coef[a*4+2], (unsigned) stage1_coef[a*4+3]);
  }
  printf("]\n");

  printf("stage2_coef = [\n");
  for(int a = 0; a < 13; a++){
    printf("0x%08X, 0x%08X, 0x%08X, 0x%08X, 0x%08X, \n", 
      (unsigned) stage2_coef[5*a+0], (unsigned) stage2_coef[5*a+1], 
      (unsigned) stage2_coef[5*a+2], (unsigned) stage2_coef[5*a+3], 
      (unsigned) stage2_coef[5*a+4]);
  }
  printf("]\n");

  printf("stage2_shr = %d\n", stage2_shr);
}