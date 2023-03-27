// Copyright 2020-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>

#include "unity_fixture.h"

#include "mic_array/util.h"

#define CHAN_COUNT    8

TEST_GROUP_RUNNER(deinterleave8) {
  RUN_TEST_CASE(deinterleave8, case0);
  RUN_TEST_CASE(deinterleave8, case1);
}

TEST_GROUP(deinterleave8);
TEST_SETUP(deinterleave8) {}
TEST_TEAR_DOWN(deinterleave8) {}


static char details1[200];
static char details2[200];

static
void set_test_details(const uint32_t expected[CHAN_COUNT], 
                      const uint32_t test_vect[CHAN_COUNT])
{
  sprintf(details1, "Expected: 0x%08X, 0x%08X, 0x%08X, 0x%08X", 
    (unsigned) expected[0], (unsigned) expected[1],
    (unsigned) expected[2], (unsigned) expected[3]);
  sprintf(details2, "Test Inputs: 0x%08X, 0x%08X, 0x%08X, 0x%08X", 
    (unsigned) test_vect[0], (unsigned) test_vect[1],
    (unsigned) test_vect[2], (unsigned) test_vect[3]);
  UNITY_SET_DETAILS(details1, details2);
}

static 
void interleave8(uint32_t res[CHAN_COUNT], 
                 const uint32_t orig[CHAN_COUNT])
{
  uint32_t mic[CHAN_COUNT];
  memcpy(mic, orig, sizeof(uint32_t) * CHAN_COUNT);
  memset(res, 0, sizeof(uint32_t) * CHAN_COUNT);

  for(int n = 0; n < CHAN_COUNT; n++){
    const unsigned p = CHAN_COUNT-1-n;
    for(int k = 0; k < 32; k++){
      const unsigned mc = k % CHAN_COUNT;
      uint32_t a = mic[mc] & 1;
      mic[mc] = mic[mc] >> 1;
      res[p] = (res[p] >> 1) & 0x7FFFFFFF;
      res[p] = res[p] | (a * ((uint32_t)0x80000000));
    }
  }
}

TEST(deinterleave8, case0)
{


  uint32_t expected[CHAN_COUNT] = {
    0x0000FFFF,
    0xFFFF0000,
    0x0F0F0F0F,
    0xF0F0F0F0,

    0x01234567,
    0x76543210,
    0x00000000,
    0xFFFFFFFF,
  };

  uint32_t vals[CHAN_COUNT] = {
    0x8AAAAAAA,
    0x86A6A696,
    0x8AAA9AAA,
    0x86A69696,
    0x8999A9A9,
    0x8595A595,
    0x899999A9,
    0x85959595, 
  };

  set_test_details(expected, vals);

  deinterleave8(&vals[0]);

  TEST_ASSERT_EQUAL_UINT32_ARRAY_MESSAGE(expected, vals, CHAN_COUNT, "");
}



TEST(deinterleave8, case1)
{
    
  srand(0x343467);

  uint32_t expected[CHAN_COUNT];
  uint32_t test_vect[CHAN_COUNT];

  const unsigned LOOP_COUNT = 4000;

  for(int rep = 0; rep < LOOP_COUNT; rep++){

    // Pick random inputs
    for(int k = 0; k < CHAN_COUNT; k++)
      expected[k] = rand();

    // Interleave them
    interleave8(test_vect, expected);

    set_test_details(expected, test_vect);

    // Deinterleave
    deinterleave8(&test_vect[0]);

    // Check result
    TEST_ASSERT_EQUAL_UINT32_ARRAY_MESSAGE(expected, test_vect, CHAN_COUNT, "");
  }
}