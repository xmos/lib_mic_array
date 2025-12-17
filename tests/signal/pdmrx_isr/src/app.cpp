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
#include "xassert.h"
#include "mic_array.h"
#include "app.h"

#define MY_STAGE2_DEC_FACTOR (1) // One sample = one block, for ease in deadlock case generation

using TPdmRxService = mic_array::StandardPdmRxService<1,1>;
TPdmRxService my_pdm_rx;

void app_pdm_rx_isr_setup(
    chanend_t c_from_host)
{
  static uint32_t pdmrx_out_block[1][MY_STAGE2_DEC_FACTOR];
  static uint32_t __attribute__((aligned (8))) pdmrx_in_block_double_buf[2][1 * MY_STAGE2_DEC_FACTOR];

  pdm_rx_conf_t pdm_rx_config;
  pdm_rx_config.pdm_out_words_per_channel = MY_STAGE2_DEC_FACTOR;
  pdm_rx_config.pdm_out_block = (uint32_t*)pdmrx_out_block;
  pdm_rx_config.pdm_in_double_buf = (uint32_t*)pdmrx_in_block_double_buf;

  my_pdm_rx.Init((port_t)c_from_host, pdm_rx_config);
  my_pdm_rx.AssertOnDroppedBlock(false);
  my_pdm_rx.InstallISR();
  my_pdm_rx.UnmaskISR();

}

void test()
{
  streaming_channel_t c_pdm;
  c_pdm = s_chan_alloc();
  app_pdm_rx_isr_setup(c_pdm.end_a);

  chanend_t c = c_pdm.end_b;

  uint32_t *pdm_samples;

  // Explained below why the 2 credit scheme deadlocks.
  // tldr; it deadlocks if there are already 2 blocks in the streaming channel buffer,
  // GetPdmBlock() gets called, sets credit=2 and the isr gets triggered between the setting of
  // credit to 2 and reading the block (s_chan_in_word). The isr, on seeing credit available attempts
  // to commit one more block to the channel buffer and deadlocks.

  // To recreate the deadlock, 3 iterations of a given sequence of events is used.
  // Note that to recreate the deadlock, we need the ISR triggered at the exact points we want, so
  // a single thread needs to be responsible for feeding pdm samples to the ISR (with interrupts masked where required)
  // and calling GetPdmBlock.
#if 0
  // iter 1
  interrupt_mask_all();
  s_chan_out_word(c, 0); // fr 0
  // Once GetPdmBlock sets cr = 2 and unmasks ISR, ISR commits fr 0 to buffer with cr = 2
  pdm_samples = my_pdm_rx.GetPdmBlock(); // read fr 0
  s_chan_out_word(c, 1); // ISR commits fr1 to buffer with cr = 1

  // iter 2
  interrupt_mask_all();
  s_chan_out_word(c, 2); // fr 2. queue fr3
  //Once GetPdmBlock sets cr = 2, ISR commits fr 2 to buffer with cr = 2
  pdm_samples = my_pdm_rx.GetPdmBlock(); // read fr1
  s_chan_out_word(c, 3); // Isr commits fr3 to buffer with cr = 1
  // At this point both frame 2 and frame 3 are in the buffer

  // Iter 3
  interrupt_mask_all();
  s_chan_out_word(c, 4); // fr 4
  pdm_samples = my_pdm_rx.GetPdmBlock(); // DEADLOCK!!. GetPdmBlock sets cr=2 and unmasks ISR causing the ISR to
                                         // get triggered and write fr4 in the buffer when it already contains fr2 and fr3
                                         // causing a deadlock.
#endif

  int frame = 0;
  for (int i=0; i<30; i++) // Running many iterations but it should deadlock in the 3rd iteration as described above
  {
    interrupt_mask_all();
    s_chan_out_word(c, frame++);

    pdm_samples = my_pdm_rx.GetPdmBlock();
    printf("Received block %d\n", *pdm_samples);

    s_chan_out_word(c, frame++);
  }
  printf("PASS\n");
  exit(0);
}

void assert_when_timeout()
{
  hwtimer_t t = hwtimer_alloc();
  unsigned long now = hwtimer_get_time(t);
  const int timeout_s = 5;

  hwtimer_set_trigger_time(t, now + (XS1_TIMER_HZ*timeout_s));
  SELECT_RES(
    CASE_THEN(t, timer_handler))
  {
    timer_handler:
      assert(0 && msg("Error: test timed out due to deadlock"));
      break;
  }

  hwtimer_free(t);
}
