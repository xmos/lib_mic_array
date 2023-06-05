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

TEST_GROUP_RUNNER(dcoe_filter) {
  RUN_TEST_CASE(dcoe_filter, states1);
  RUN_TEST_CASE(dcoe_filter, states4);
  RUN_TEST_CASE(dcoe_filter, states8);
  RUN_TEST_CASE(dcoe_filter, states32);
}

TEST_GROUP(dcoe_filter);
TEST_SETUP(dcoe_filter) {}
TEST_TEAR_DOWN(dcoe_filter) {}

}


template <unsigned CHANS, unsigned ITER_COUNT>
static
void test_dcoe_filter()
{

  srand(7685664);

  dcoe_chan_state_t states[CHANS];
  int32_t input[CHANS];
  
  double f_states[CHANS];

  dcoe_state_init(states, CHANS);
  for(int k = 0; k < CHANS; k++) f_states[k] = 0.0;

  for(int r = 0; r < ITER_COUNT; r++){
    
    int32_t output[CHANS];
    double f_output[CHANS];
    int32_t expected[CHANS];

    for(int k = 0; k < CHANS; k++)
      input[k] = rand();

    // y[t] = (252.0/256) * y[t-1] - x[t-1] + x[t]
    for(int k = 0; k < CHANS; k++){
      f_output[k] = f_states[k] + input[k];
      expected[k] = (int32_t) round(f_output[k]);
    }

    dcoe_filter(output, states, input, CHANS);

    TEST_ASSERT_EQUAL_INT32_ARRAY(expected, output, CHANS);

    // If we don't pin the float state to the int state they will diverge. This
    // isn't ideal because it means we're not really testing a whole lot, but we
    // can improve the test cases later.
    for(int k = 0; k < CHANS; k++)
      f_states[k] = states[k].prev_y >> 32;
    
  }
}

extern "C" {
  
TEST(dcoe_filter, states1)  { test_dcoe_filter<1,1000>(); }
TEST(dcoe_filter, states4)  { test_dcoe_filter<4,1000>(); }
TEST(dcoe_filter, states8)  { test_dcoe_filter<8,1000>(); }
TEST(dcoe_filter, states32) { test_dcoe_filter<32,1000>(); }

}