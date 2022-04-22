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

TEST_GROUP_RUNNER(dcoe_state_init) {
  RUN_TEST_CASE(dcoe_state_init, dcoe_state_init);
}

TEST_GROUP(dcoe_state_init);
TEST_SETUP(dcoe_state_init) {}
TEST_TEAR_DOWN(dcoe_state_init) {}

}


extern "C" {
  
/**
 * Currently initialization is just zeroing out the states.
 */
TEST(dcoe_state_init, dcoe_state_init)
{
  constexpr unsigned MAX_STATES = 400;
  constexpr unsigned LOOP_COUNT = 4000;

  srand(57355544);

  dcoe_chan_state_t states[MAX_STATES];

  auto* start_state = &states[1];

  for(int r = 0; r < LOOP_COUNT; r++){

    memset(states, 0x55, sizeof(states));

    auto stateA = states[0];

    unsigned N = rand() % (MAX_STATES-2);

    dcoe_state_init(start_state, N);

    TEST_ASSERT_EQUAL_INT64(stateA.prev_y, states[0].prev_y);
    TEST_ASSERT_EQUAL_INT64(stateA.prev_y, states[N+1].prev_y);

    for(int k = 0; k < N; k++){
      TEST_ASSERT_EQUAL_INT64(0, start_state[k].prev_y);
    }
  }
}

}