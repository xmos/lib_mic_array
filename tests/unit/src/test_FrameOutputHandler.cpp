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

#include "unity_fixture.h"

#include "mic_array/cpp/OutputHandler.hpp"

extern "C" {

  TEST_GROUP_RUNNER(FrameOutputHandler) {
    RUN_TEST_CASE(FrameOutputHandler, case_1x1);
    RUN_TEST_CASE(FrameOutputHandler, case_1x16);
    RUN_TEST_CASE(FrameOutputHandler, case_1x256);
    RUN_TEST_CASE(FrameOutputHandler, case_1x1024);
    RUN_TEST_CASE(FrameOutputHandler, case_2x1);
    RUN_TEST_CASE(FrameOutputHandler, case_2x16);
    RUN_TEST_CASE(FrameOutputHandler, case_2x256);
    RUN_TEST_CASE(FrameOutputHandler, case_2x1024);
    RUN_TEST_CASE(FrameOutputHandler, case_4x1);
    RUN_TEST_CASE(FrameOutputHandler, case_4x16);
    RUN_TEST_CASE(FrameOutputHandler, case_4x256);
    RUN_TEST_CASE(FrameOutputHandler, case_4x1024);
    
    RUN_TEST_CASE(FrameOutputHandler, multibuffer);
  }

  TEST_GROUP(FrameOutputHandler);
  TEST_SETUP(FrameOutputHandler) {}
  TEST_TEAR_DOWN(FrameOutputHandler) {}

}

template <unsigned MIC_COUNT, unsigned SAMPLE_COUNT>
class MockFrameTransmitter
{
  public:

    unsigned OutputFrame_called = 0;

    int32_t last_frame[MIC_COUNT][SAMPLE_COUNT];
    int32_t* last_frame_ptr;

    MockFrameTransmitter() {}

    void OutputFrame(int32_t frame[MIC_COUNT][SAMPLE_COUNT])
    {
      OutputFrame_called++;
      memcpy(&last_frame[0][0], &frame[0][0], sizeof(last_frame));
      last_frame_ptr = &frame[0][0];
    }
};


template <unsigned CHANS, unsigned SAMPLE_COUNT>
static
void test_FrameOutputHandler()
{
  srand(45634*CHANS + SAMPLE_COUNT);
  
  constexpr unsigned LOOP_COUNT=400;

  using TFrameOutputHandler = mic_array::FrameOutputHandler<CHANS,SAMPLE_COUNT,MockFrameTransmitter>;

  TFrameOutputHandler handler;
  
  for(int r = 0; r < LOOP_COUNT; r++){

    TEST_ASSERT_EQUAL(r, handler.FrameTx.OutputFrame_called);

    int32_t exp_frame[CHANS][SAMPLE_COUNT];

    for(int s = 0; s < SAMPLE_COUNT; s++){

      int32_t sample[CHANS];
      for(int c = 0; c < CHANS; c++){
        sample[c] = rand();
        exp_frame[c][s] = sample[c];
      }

      handler.OutputSample(sample);

      if(s != SAMPLE_COUNT-1)
        TEST_ASSERT_EQUAL(r, handler.FrameTx.OutputFrame_called);
      else
        TEST_ASSERT_EQUAL(r+1, handler.FrameTx.OutputFrame_called);
    }

    TEST_ASSERT_EQUAL_INT32_ARRAY(&exp_frame[0][0], &handler.FrameTx.last_frame[0][0], CHANS * SAMPLE_COUNT);
    
  }
}

extern "C" {
  
  TEST(FrameOutputHandler, case_1x1)    { test_FrameOutputHandler<1,1>();    }
  TEST(FrameOutputHandler, case_1x16)   { test_FrameOutputHandler<1,16>();   }
  TEST(FrameOutputHandler, case_1x256)  { test_FrameOutputHandler<1,256>();  }
  TEST(FrameOutputHandler, case_1x1024) { test_FrameOutputHandler<1,1024>(); }
  TEST(FrameOutputHandler, case_2x1)    { test_FrameOutputHandler<2,1>();    }
  TEST(FrameOutputHandler, case_2x16)   { test_FrameOutputHandler<2,16>();   }
  TEST(FrameOutputHandler, case_2x256)  { test_FrameOutputHandler<2,256>();  }
  TEST(FrameOutputHandler, case_2x1024) { test_FrameOutputHandler<2,1024>(); }
  TEST(FrameOutputHandler, case_4x1)    { test_FrameOutputHandler<4,1>();    }
  TEST(FrameOutputHandler, case_4x16)   { test_FrameOutputHandler<4,16>();   }
  TEST(FrameOutputHandler, case_4x256)  { test_FrameOutputHandler<4,256>();  }
  TEST(FrameOutputHandler, case_4x1024) { test_FrameOutputHandler<4,1024>(); }
}


template <unsigned CHANS, unsigned SAMPLE_COUNT>
static
void test_FrameOutputHandlerB()
{

}

extern "C" {
  
  TEST(FrameOutputHandler, multibuffer)
  {
    constexpr unsigned CHANS = 1;
    constexpr unsigned SAMPLE_COUNT = 16;
    constexpr unsigned FRAME_COUNT = 4;

    srand(56456*CHANS + SAMPLE_COUNT);

    using TFrameOutputHandler = mic_array::FrameOutputHandler<CHANS,SAMPLE_COUNT,MockFrameTransmitter,FRAME_COUNT>;

    TFrameOutputHandler handler;

    int32_t exp_frame[CHANS][SAMPLE_COUNT];

    TEST_ASSERT_EQUAL(0, handler.FrameTx.OutputFrame_called);

    for(int s = 0; s < SAMPLE_COUNT; s++){
      int32_t sample[CHANS];
      for(int c = 0; c < CHANS; c++){
        sample[c] = rand();
        exp_frame[c][s] = sample[c];
      }
      handler.OutputSample(sample);
    }

    TEST_ASSERT_EQUAL(1, handler.FrameTx.OutputFrame_called);

    TEST_ASSERT_EQUAL_INT32_ARRAY(&exp_frame[0][0], handler.FrameTx.last_frame_ptr, CHANS * SAMPLE_COUNT);

    // If FRAME_COUNT had been 1, any more calls to OutputSample() would start overwriting the first frame.
    auto* first_frame_ptr = handler.FrameTx.last_frame_ptr;
    
    int32_t sample_0x55[CHANS];
    for(int c = 0; c < CHANS; c++)
      sample_0x55[c] = 0x55555555;

    for(int f = 0; f < (FRAME_COUNT-1); f++){
      for(int s = 0; s < SAMPLE_COUNT; s++){
        handler.OutputSample(sample_0x55);
      }

      TEST_ASSERT_EQUAL_INT32_ARRAY(&exp_frame[0][0], first_frame_ptr, CHANS * SAMPLE_COUNT);
    }

    // Any more output samples should overwrite the first frame
    TEST_ASSERT_NOT_EQUAL_INT32(sample_0x55[0], first_frame_ptr[0]);
    handler.OutputSample(sample_0x55);
    TEST_ASSERT_EQUAL_INT32(sample_0x55[0], first_frame_ptr[0]);

  }

}