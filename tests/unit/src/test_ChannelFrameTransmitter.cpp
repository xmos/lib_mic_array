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

#include "mic_array/cpp/OutputHandler.hpp"

extern "C" {

  channel_t c_frames;

  TEST_GROUP_RUNNER(ChannelFrameTransmitter) {
    RUN_TEST_CASE(ChannelFrameTransmitter, NoArgConstructor);
    RUN_TEST_CASE(ChannelFrameTransmitter, OneArgConstructor);
    RUN_TEST_CASE(ChannelFrameTransmitter, SetChannel);
    
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_1x1   );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_1x16  );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_1x256 );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_1x1024);
    
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_2x1   );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_2x16  );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_2x256 );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_2x1024);
    
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_4x1   );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_4x16  );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_4x256 );
    RUN_TEST_CASE(ChannelFrameTransmitter, OutputFrame_4x1024);
  }

  TEST_GROUP(ChannelFrameTransmitter);

  TEST_SETUP(ChannelFrameTransmitter) {
    c_frames = chan_alloc();
  }

  TEST_TEAR_DOWN(ChannelFrameTransmitter) {
    chan_free(c_frames);
  }


  static unsigned stack[8000];
  static void* stack_start = stack_base(stack, 8000);

}

template <unsigned CHANS, unsigned SAMPLE_COUNT>
static void send_frame(void* vframe)
{
  auto frame = reinterpret_cast<int32_t (*)[SAMPLE_COUNT]>(vframe);

  mic_array::ChannelFrameTransmitter<CHANS,SAMPLE_COUNT> frame_tx(c_frames.end_a);

  frame_tx.OutputFrame(frame);

}

template <unsigned CHANS, unsigned SAMPLE_COUNT>
static
void test_ChannelFrameTransmitter()
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

    ma_frame_rx(&received[0][0], c_frames.end_b, CHANS, SAMPLE_COUNT);

    TEST_ASSERT_EQUAL_INT32_ARRAY(&exp_frame[0][0], &received[0][0], CHANS * SAMPLE_COUNT);
  }
}

extern "C" {

  TEST(ChannelFrameTransmitter, NoArgConstructor) {
    if(1){
      auto frame_tx = mic_array::ChannelFrameTransmitter<1,1>();
      TEST_ASSERT_EQUAL_UINT32(0, frame_tx.GetChannel());
    }
    if(1){
      auto frame_tx = mic_array::ChannelFrameTransmitter<8,1>();
      TEST_ASSERT_EQUAL_UINT32(0, frame_tx.GetChannel());
    }
    if(1){
      auto frame_tx = mic_array::ChannelFrameTransmitter<2,4>();
      TEST_ASSERT_EQUAL_UINT32(0, frame_tx.GetChannel());
    }
    if(1){
      auto frame_tx = mic_array::ChannelFrameTransmitter<4,256>();
      TEST_ASSERT_EQUAL_UINT32(0, frame_tx.GetChannel());
    }
  }

  TEST(ChannelFrameTransmitter, OneArgConstructor) {
    srand(57645674);
    if(1){
      uint32_t c = rand();
      auto frame_tx = mic_array::ChannelFrameTransmitter<1,1>(c);
      TEST_ASSERT_EQUAL_UINT32(c, frame_tx.GetChannel());
    }
    if(1){
      uint32_t c = rand();
      auto frame_tx = mic_array::ChannelFrameTransmitter<8,1>(c);
      TEST_ASSERT_EQUAL_UINT32(c, frame_tx.GetChannel());
    }
    if(1){
      uint32_t c = rand();
      auto frame_tx = mic_array::ChannelFrameTransmitter<2,4>(c);
      TEST_ASSERT_EQUAL_UINT32(c, frame_tx.GetChannel());
    }
    if(1){
      uint32_t c = rand();
      auto frame_tx = mic_array::ChannelFrameTransmitter<4,256>(c);
      TEST_ASSERT_EQUAL_UINT32(c, frame_tx.GetChannel());
    }
  }

  TEST(ChannelFrameTransmitter, SetChannel) {

    srand(45746236);

    auto frame_tx = mic_array::ChannelFrameTransmitter<4,8>();
    TEST_ASSERT_EQUAL_UINT32(0, frame_tx.GetChannel());

    for(int k = 0; k < 400; k++){
      uint32_t c = rand();
      frame_tx.SetChannel(c);
      TEST_ASSERT_EQUAL_UINT32(c, frame_tx.GetChannel());
    }
  }
  
  TEST(ChannelFrameTransmitter, OutputFrame_1x1)    { test_ChannelFrameTransmitter<1,1>();    }
  TEST(ChannelFrameTransmitter, OutputFrame_1x16)   { test_ChannelFrameTransmitter<1,16>();   }
  TEST(ChannelFrameTransmitter, OutputFrame_1x256)  { test_ChannelFrameTransmitter<1,256>();  }
  TEST(ChannelFrameTransmitter, OutputFrame_1x1024) { test_ChannelFrameTransmitter<1,1024>(); }
  
  TEST(ChannelFrameTransmitter, OutputFrame_2x1)    { test_ChannelFrameTransmitter<2,1>();    }
  TEST(ChannelFrameTransmitter, OutputFrame_2x16)   { test_ChannelFrameTransmitter<2,16>();   }
  TEST(ChannelFrameTransmitter, OutputFrame_2x256)  { test_ChannelFrameTransmitter<2,256>();  }
  TEST(ChannelFrameTransmitter, OutputFrame_2x1024) { test_ChannelFrameTransmitter<2,1024>(); }
  
  TEST(ChannelFrameTransmitter, OutputFrame_4x1)    { test_ChannelFrameTransmitter<4,1>();    }
  TEST(ChannelFrameTransmitter, OutputFrame_4x16)   { test_ChannelFrameTransmitter<4,16>();   }
  TEST(ChannelFrameTransmitter, OutputFrame_4x256)  { test_ChannelFrameTransmitter<4,256>();  }
  TEST(ChannelFrameTransmitter, OutputFrame_4x1024) { test_ChannelFrameTransmitter<4,1024>(); }

}