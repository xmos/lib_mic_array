// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <iostream>
#include <fstream>
#include <cstdio>
#include <cstdint>

#include <xcore/channel.h>
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


void app_output_task(chanend_t c_frames_in)
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


  // receive the output of the mic array and send it to the host
  int32_t frame[CHAN_COUNT][SAMPLES_PER_FRAME];
  while(1){
    ma_frame_rx(&frame[0][0], c_frames_in, CHAN_COUNT, SAMPLES_PER_FRAME);

    // Send it to host sample by sample rather than channel by channel
    for(int smp = 0; smp < SAMPLES_PER_FRAME; smp++) {
      for(int ch = 0; ch < CHAN_COUNT; ch++){
        xscope_int(DATA_OUT, frame[ch][smp]);
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