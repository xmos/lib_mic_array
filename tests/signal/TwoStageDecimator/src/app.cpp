// Copyright 2020-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>

#include <platform.h>
#include <xcore/select.h>
#include <xcore/parallel.h>
#include <xcore/chanend.h>
#include <xcore/channel.h>
#include <xcore/hwtimer.h>
#include <xcore/channel_streaming.h>

extern "C" {
#include <xscope.h>
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

#define BUFF_SIZE    256

typedef chanend_t streaming_chanend_t;

// Will be loaded from file
static uint32_t test_stage1_coef[128];

static int32_t test_stage2_coef[S2_TAPS];
static right_shift_t test_stage2_shr;

DECLARE_JOB(run, (chanend_t));
DECLARE_JOB(host_words_to_app, (chanend_t, streaming_chanend_t));

// ------------------------------- HELPER FUNCTIONS -------------------------------

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

  using TDecimator = mic_array::TwoStageDecimator<CHAN_COUNT>;

  TDecimator dec;
  static int32_t stg1_filter_state[CHAN_COUNT][8];
  static int32_t stg2_filter_state[CHAN_COUNT][S2_TAPS];

  mic_array_decimator_conf_t decimator_conf;
  mic_array_filter_conf_t filter_conf[2];

  memset(&decimator_conf, 0, sizeof(decimator_conf));

  decimator_conf.filter_conf = &filter_conf[0];
  decimator_conf.num_filter_stages = 2;
  filter_conf[0].coef = (int32_t*)test_stage1_coef;
  filter_conf[0].num_taps = 256;
  filter_conf[0].decimation_factor = 32;
  filter_conf[0].state = (int32_t*)stg1_filter_state;
  filter_conf[0].state_words_per_channel = filter_conf[0].num_taps/32;

  filter_conf[1].coef = (int32_t*)test_stage2_coef;
  filter_conf[1].decimation_factor = S2_DEC_FACT;
  filter_conf[1].num_taps = S2_TAPS;
  filter_conf[1].shr = test_stage2_shr;
  filter_conf[1].state_words_per_channel = filter_conf[1].num_taps;
  filter_conf[1].state = (int32_t*)stg2_filter_state;

  dec.Init(decimator_conf);

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


void host_words_to_app(chanend_t c_from_host, streaming_chanend_t c_to_app)
{
  xscope_connect_data_from_host(c_from_host);

  // +3 is for any partial word at the end of the read
  char buff[BUFF_SIZE+3];
  int buff_lvl = 0;

  SELECT_RES(
    CASE_THEN(c_from_host, c_from_host_handler)
  ){
  c_from_host_handler:{
    int dd;
    xscope_data_from_host(c_from_host, &buff[0], &dd);
    dd--; // last byte is always 0 (for some reason)
    buff_lvl += dd;
    
    // Send all (complete) words to app
    int* next_word = ((int*)(void*) &buff[0]);
    while(buff_lvl >= sizeof(int)){
      s_chan_out_word(c_to_app, next_word[0]);
      next_word++;
      buff_lvl -= sizeof(int);
    }

    // if there's 1-3 bytes left move it to the front.
    if(buff_lvl) {
      memmove(&buff[0], &next_word[0], buff_lvl);
    }

    continue;
  }}
}


int main()
{
  streaming_channel_t c_to_app = s_chan_alloc();
  
  // xscope init note: only one channel end is needed
  // the second one and the xscope service will be
  // automatically started and routed by the tools
  chanend_t xscope_chan = chanend_alloc();
  xscope_mode_lossless();

  PAR_JOBS(
    PJOB(host_words_to_app, (xscope_chan, c_to_app.end_a)),
    PJOB(run, (c_to_app.end_b))
  );
  
  s_chan_free(c_to_app);
  
  printf("Done.\n");
  return 0;
}
