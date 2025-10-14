// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <iostream>
#include <fstream>
#include <cstdio>
#include <cstring>

#include <print.h>
#include <string.h>
#include <xcore/select.h>

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


using TPdmRxService = mic_array::StandardPdmRxService<CHAN_COUNT,CHAN_COUNT,STAGE2_DEC_FACTOR>;

TPdmRxService my_pdm_rx;


void app_pdm_rx_isr_setup(
    chanend_t c_from_host)
{
  my_pdm_rx.Init((port_t)c_from_host);
  my_pdm_rx.AssertOnDroppedBlock(false);
  my_pdm_rx.InstallISR();
  my_pdm_rx.UnmaskISR();

}

const unsigned fifo_entries = (TEST_SZ/STAGE2_DEC_FACTOR) + 1; // should never overflow
typedef int32_t pdm_frame_t[CHAN_COUNT][STAGE2_DEC_FACTOR];
pdm_frame_t frame_fifo[fifo_entries];
uint8_t fifo_idx = 0;

void app_recv_pdm_block_task(chanend_t c_fifo)
{
  while(1)
  {
    uint32_t* pdm_samples = my_pdm_rx.GetPdmBlock();
    memcpy(frame_fifo[fifo_idx], pdm_samples, sizeof(pdm_frame_t));
    chanend_out_byte(c_fifo, fifo_idx++);
    if(fifo_idx == 2)
    {
      printintln(4444);
      delay_ticks(6250*4);
    }
    if(fifo_idx == 3)
    {
      printintln(5555);
      delay_ticks(6250);
    }
    if(fifo_idx == fifo_entries){
        asm volatile("ecallf %0":: "r" (0)); // Dont expect wraparound
    }
  }
}

#if 0
void app_fifo_to_xscope_task(chanend_t c_fifo)
{
  while(1){
    uint8_t idx = chanend_in_byte(c_fifo);
    pdm_frame_t *ptr = &frame_fifo[idx];
    if(idx == ((TEST_SZ/STAGE2_DEC_FACTOR)-1))
    {
      printf("hooray!! done.\n");
      _Exit(0);
    }
  }
}
#endif

void app_fifo_to_xscope_task(chanend_t c_fifo, chanend_t c_terminate)
{
  int8_t idx = -1;
  SELECT_RES(
    CASE_THEN(c_fifo, event_fifo_write),
    CASE_THEN(c_terminate, event_terminate)
  )
  {
    event_fifo_write:
    {
      idx = chanend_in_byte(c_fifo);
      pdm_frame_t *ptr = &frame_fifo[idx];
    }
    continue;
    event_terminate:
    {
      printf("Terminating. Received %d blocks.\n", idx+1);
      for(int i=0; i<idx+1; i++)
      {
        printf("block %d:\n", i);
        int32_t *ptr = (int32_t*)frame_fifo[i];
        for(int j=0; j<sizeof(pdm_frame_t)/sizeof(int32_t); j++)
        {
          printf("%d\n", ptr[j]);
        }
      }
      int _ = chan_in_word(c_terminate);
      (void)_;
      _Exit(0);
    }
    continue;
  }
}
