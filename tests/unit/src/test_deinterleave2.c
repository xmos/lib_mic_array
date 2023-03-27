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

#define CHAN_COUNT    2

TEST_GROUP_RUNNER(deinterleave2) {
  RUN_TEST_CASE(deinterleave2, case0);
  RUN_TEST_CASE(deinterleave2, case1);
}

TEST_GROUP(deinterleave2);
TEST_SETUP(deinterleave2) {}
TEST_TEAR_DOWN(deinterleave2) {}


static char details1[200];
static char details2[200];

static
void set_test_details(const uint32_t expected[CHAN_COUNT], 
                      const uint32_t test_vect[CHAN_COUNT])
{
  sprintf(details1, "Expected: 0x%08X, 0x%08X", (unsigned) expected[0],
                                                (unsigned) expected[1]);
  sprintf(details2, "Test Inputs: 0x%08X, 0x%08X", (unsigned) test_vect[0],
                                                   (unsigned) test_vect[1]);
  UNITY_SET_DETAILS(details1, details2);
}

static 
void interleave2(uint32_t res[CHAN_COUNT], 
                 const uint32_t orig[CHAN_COUNT])
{
  uint32_t mic[CHAN_COUNT];
  memcpy(mic, orig, sizeof(uint32_t) * CHAN_COUNT);
  memset(res, 0, sizeof(uint32_t) * CHAN_COUNT);

  for(int n = 0; n < CHAN_COUNT; n++){
    const unsigned p = CHAN_COUNT-1-n;
    for(int k = 0; k < 32; k++){
      // printf("n = %d\n", n);
      // printf("p = %d\n", p);
      // printf("k = %d\n", k);
      const unsigned mc = k % CHAN_COUNT;
      // printf("mc = %u\n", mc);
      uint32_t a = mic[mc] & 1;
      // printf("a = %lu\n", a);
      // printf("mic[%u] = 0x%08X", mc, (unsigned) mic[mc]);
      mic[mc] = mic[mc] >> 1;
      // printf(" --> 0x%08X\n", (unsigned) mic[mc]);

      // printf("res[%u] = 0x%08X", p, (unsigned) res[p]);
      res[p] = (res[p] >> 1) & 0x7FFFFFFF;
      res[p] = res[p] | (a * ((uint32_t)0x80000000));
      // printf(" --> 0x%08X\n", (unsigned) res[p]);
      // printf("----\n");
    }
  }
}

TEST(deinterleave2, case0)
{
  uint32_t expected[CHAN_COUNT] = {
    0xAA00FFFF,
    0xFFFF0044,
  };

  uint32_t vals[CHAN_COUNT] = {
    0xEEEEAAAA,
    0x55557575,
  };

  set_test_details(expected, vals);

  deinterleave2(&vals[0]);

  TEST_ASSERT_EQUAL_UINT32_ARRAY_MESSAGE(expected, vals, CHAN_COUNT, "");
}



TEST(deinterleave2, case1)
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
    interleave2(test_vect, expected);

    set_test_details(expected, test_vect);

    // Deinterleave
    deinterleave2(&test_vect[0]);

    // Check result
    TEST_ASSERT_EQUAL_UINT32_ARRAY_MESSAGE(expected, test_vect, CHAN_COUNT, "");
  }
}