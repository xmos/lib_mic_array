// Copyright 2020-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>

#include <xcore/thread.h>
#include <xcore/channel.h>
#include <xcore/channel_transaction.h>

#include "unity_fixture.h"

#include "mic_array/frame_transfer.h"

extern "C" {

  static
  struct {
    channel_t c_frames;
  } rx_ctx;

  TEST_GROUP_RUNNER(ma_frame_tx_rx) {
    RUN_TEST_CASE(ma_frame_tx_rx, case_1chan_1samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_1chan_16samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_1chan_256samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_1chan_1024samp);
    
    RUN_TEST_CASE(ma_frame_tx_rx, case_2chan_1samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_2chan_16samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_2chan_256samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_2chan_1024samp);
    
    RUN_TEST_CASE(ma_frame_tx_rx, case_4chan_1samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_4chan_16samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_4chan_256samp);
    RUN_TEST_CASE(ma_frame_tx_rx, case_4chan_1024samp);
  }

  TEST_GROUP(ma_frame_tx_rx);

  TEST_SETUP(ma_frame_tx_rx) {
    rx_ctx.c_frames = chan_alloc();
  }

  TEST_TEAR_DOWN(ma_frame_tx_rx) {
    chan_free(rx_ctx.c_frames);
  }


  static unsigned stack[8000];
  static void* stack_start = stack_base(stack, 8000);

}

template <unsigned CHANS, unsigned SAMPLE_COUNT>
static void send_frame(void* vframe)
{
  int32_t* frame = (int32_t*) vframe;

  // Send the frame we were told to send
  ma_frame_tx(rx_ctx.c_frames.end_a, frame, CHANS, SAMPLE_COUNT);

}

template <unsigned CHANS, unsigned SAMPLE_COUNT>
static
void test_ma_frame_tx_rx()
{
  srand(7685664*CHANS + SAMPLE_COUNT);
  
  constexpr unsigned LOOP_COUNT=400;
  
  for(int r = 0; r < LOOP_COUNT; r++){
    int32_t exp_frame[CHANS][SAMPLE_COUNT];
    
    for(int c = 0; c < CHANS; c++)
      for(int s = 0; s < SAMPLE_COUNT; s++)
        exp_frame[c][s] = rand();

    run_async( send_frame<CHANS,SAMPLE_COUNT>, &exp_frame[0][0], stack_start);

    int32_t received[CHANS][SAMPLE_COUNT];

    ma_frame_rx(&received[0][0], rx_ctx.c_frames.end_b, CHANS, SAMPLE_COUNT);

    TEST_ASSERT_EQUAL_INT32_ARRAY(&exp_frame[0][0], &received[0][0], CHANS * SAMPLE_COUNT);
  }
}

extern "C" {
  
  TEST(ma_frame_tx_rx, case_1chan_1samp)     { test_ma_frame_tx_rx<1,1>();    }
  TEST(ma_frame_tx_rx, case_1chan_16samp)    { test_ma_frame_tx_rx<1,16>();   }
  TEST(ma_frame_tx_rx, case_1chan_256samp)   { test_ma_frame_tx_rx<1,256>();  }
  TEST(ma_frame_tx_rx, case_1chan_1024samp)  { test_ma_frame_tx_rx<1,1024>(); }

  TEST(ma_frame_tx_rx, case_2chan_1samp)     { test_ma_frame_tx_rx<2,1>();    }
  TEST(ma_frame_tx_rx, case_2chan_16samp)    { test_ma_frame_tx_rx<2,16>();   }
  TEST(ma_frame_tx_rx, case_2chan_256samp)   { test_ma_frame_tx_rx<2,256>();  }
  TEST(ma_frame_tx_rx, case_2chan_1024samp)  { test_ma_frame_tx_rx<2,1024>(); }

  TEST(ma_frame_tx_rx, case_4chan_1samp)     { test_ma_frame_tx_rx<4,1>();    }
  TEST(ma_frame_tx_rx, case_4chan_16samp)    { test_ma_frame_tx_rx<4,16>();   }
  TEST(ma_frame_tx_rx, case_4chan_256samp)   { test_ma_frame_tx_rx<4,256>();  }
  TEST(ma_frame_tx_rx, case_4chan_1024samp)  { test_ma_frame_tx_rx<4,1024>(); }

}