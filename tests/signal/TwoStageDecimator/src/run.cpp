// Copyright 2020-2022 XMOS LIMITED.
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

#ifndef CHAN_COUNT
# error CHAN_COUNT must be defined.
#endif
#ifndef S2_TAPS
# error S2_TAPS must be defined.
#endif
#ifndef S2_DEC_FACT
# error S2_DEC_FACT must be defined.
#endif

// Will be loaded from file
static uint32_t test_stage1_coef[128];

static int32_t test_stage2_coef[S2_TAPS];
static right_shift_t test_stage2_shr;


void load_stage1(chanend_t c_from_host)
{
  printf("Listening for 1st stage filter coefficients..\n");
  s_chan_in_buf_word(c_from_host,
                     &test_stage1_coef[0],
                     sizeof(test_stage1_coef)/sizeof(uint32_t));
  printf("Stage 1 coefficients received.\n");
}

void load_stage2(chanend_t c_from_host)
{
  printf("Listening for 2nd stage filter coefficients..\n");
  s_chan_in_buf_word(c_from_host,
                     reinterpret_cast<uint32_t*>(&test_stage2_coef[0]),
                     sizeof(test_stage2_coef)/sizeof(int32_t));
  test_stage2_shr = s_chan_in_word(c_from_host);
  printf("Stage 2 coefficients received.\n");
}


void process_signal(chanend_t c_from_host)
{
  constexpr unsigned BLOCK_WORDS = CHAN_COUNT * S2_DEC_FACT;
 
  using TDecimator = mic_array::TwoStageDecimator<CHAN_COUNT,
                                                  S2_DEC_FACT,
                                                  S2_TAPS>;

  TDecimator dec;
  dec.Init(const_cast<uint32_t*>(test_stage1_coef), 
           test_stage2_coef, test_stage2_shr);

  // Host will tell us how many blocks it intends to send
  unsigned block_count = s_chan_in_word(c_from_host);

  uint32_t buffer[BLOCK_WORDS];
  int32_t sample_out[CHAN_COUNT];

  printf("Processing %u blocks of PDM samples..\n", block_count);
  for(int k = 0; k < block_count; k++){
    s_chan_in_buf_word(c_from_host, &buffer[0], BLOCK_WORDS);
    dec.ProcessBlock(sample_out, buffer);
    for(int c = 0; c < CHAN_COUNT; c++){
      xscope_int(DATA_OUT, sample_out[c]);
    }
  }
  printf("Finished processing PDM signal.\n");
}

extern "C"
void run(chanend_t c_from_host)
{
  // Tell the host script what parameters are currently being used
  xscope_int(META_OUT, CHAN_COUNT);
  xscope_int(META_OUT, 256); // S1_TAP_COUNT
  xscope_int(META_OUT, 32); // S1_DEC_FACTOR
  xscope_int(META_OUT, S2_TAPS);
  xscope_int(META_OUT, S2_DEC_FACT);
  
  load_stage1(c_from_host);
  load_stage2(c_from_host);

  process_signal(c_from_host);
}