// Copyright 2020-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>

#include "unity_fixture.h"

#include "mic_array/dc_elimination.h"
#include "mic_array/cpp/SampleFilter.hpp"

extern "C" {

TEST_GROUP_RUNNER(DcoeSampleFilter) {
  RUN_TEST_CASE(DcoeSampleFilter, states1);
  RUN_TEST_CASE(DcoeSampleFilter, states4);
  RUN_TEST_CASE(DcoeSampleFilter, states8);
  RUN_TEST_CASE(DcoeSampleFilter, states32);
}

TEST_GROUP(DcoeSampleFilter);
TEST_SETUP(DcoeSampleFilter) {}
TEST_TEAR_DOWN(DcoeSampleFilter) {}

}

// This extension is just a way to make the state accessible
template<unsigned CHANS>
class TestDcoeSampleFilter : public mic_array::DcoeSampleFilter<CHANS>
{
  public:
    TestDcoeSampleFilter() : mic_array::DcoeSampleFilter<CHANS>() {}
    dcoe_chan_state_t GetState(unsigned channel) {
      return this->state[channel];
    }
};

template <unsigned CHANS, unsigned ITER_COUNT>
static
void test_DcoeSampleFilter()
{

  srand(7685664);

  TestDcoeSampleFilter<CHANS> filter;
  int32_t input[CHANS];
  
  double f_states[CHANS];

  filter.Init();

  for(int k = 0; k < CHANS; k++) f_states[k] = 0.0;

  for(int r = 0; r < ITER_COUNT; r++){
    
    double f_output[CHANS];
    int32_t expected[CHANS];

    for(int k = 0; k < CHANS; k++)
      input[k] = rand();

    // y[t] = (252.0/256) * y[t-1] - x[t-1] + x[t]
    for(int k = 0; k < CHANS; k++){
      f_output[k] = f_states[k] + input[k];
      expected[k] = (int32_t) round(f_output[k]);
    }

    filter.Filter(input);

    TEST_ASSERT_EQUAL_INT32_ARRAY(expected, input, CHANS);

    // If we don't pin the float state to the int state they will diverge. This
    // isn't ideal because it means we're not really testing a whole lot, but we
    // can improve the test cases later.
    for(int k = 0; k < CHANS; k++)
      f_states[k] = filter.GetState(k).prev_y >> 32;
    
  }
}

extern "C" {
  
TEST(DcoeSampleFilter, states1)  { test_DcoeSampleFilter<1,1000>(); }
TEST(DcoeSampleFilter, states4)  { test_DcoeSampleFilter<4,1000>(); }
TEST(DcoeSampleFilter, states8)  { test_DcoeSampleFilter<8,1000>(); }
TEST(DcoeSampleFilter, states32) { test_DcoeSampleFilter<32,1000>(); }

}