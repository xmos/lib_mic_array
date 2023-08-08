// Copyright 2020-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>

#include "unity_fixture.h"

#include "mic_array/util.h"

#define CHAN_COUNT    16

TEST_GROUP_RUNNER(deinterleave16) {
  RUN_TEST_CASE(deinterleave16, case0);
  RUN_TEST_CASE(deinterleave16, case1);
}

TEST_GROUP(deinterleave16);
TEST_SETUP(deinterleave16) {}
TEST_TEAR_DOWN(deinterleave16) {}


/*
This test ensures that the PDM samples corresponding to channel K end up in
the kth word after deinterleaving.
*/
TEST(deinterleave16, case0)
{

  for(int k = 0; k < 16; k++){
    uint32_t vals[CHAN_COUNT] = {0};

    // Set only those bits corresponding to channel k.
    // after deinterleaving, this should mean each vals[n] == 0, except for
    // vals[k] == 0xFFFFFFFF
    for(int n = 0; n < CHAN_COUNT; n++)
      vals[n] = 0x00010001 << k;

    // Test prints to interpret the deinterlaving order
    // printf("\n\n");
    // printf("Before:\n");
    // for(int n = 0; n < CHAN_COUNT/2; n++)
    //   printf("0x%08X, ", (unsigned) vals[n]);
    // printf("\n");
    // for(int n = CHAN_COUNT/2; n < CHAN_COUNT; n++)
    //   printf("0x%08X, ", (unsigned) vals[n]);
    // printf("\n\n");

    deinterleave16(&vals[0]);

    // Test prints to interpret the deinterlaving order
    // printf("After:\n");
    // for(int n = 0; n < CHAN_COUNT/2; n++)
    //   printf("0x%08X, ", (unsigned) vals[n]);
    // printf("\n");
    // for(int n = CHAN_COUNT/2; n < CHAN_COUNT; n++)
    //   printf("0x%08X, ", (unsigned) vals[n]);
    // printf("\n\n");

    for(int n = 0; n < CHAN_COUNT; n++){
      uint32_t exp = (n == k) ? 0xFFFFFFFF : 0x00000000;
      TEST_ASSERT_EQUAL_UINT32_MESSAGE(exp, vals[n], "");
    }

  }
}

/*
This test ensures that the PDM samples within an output word are in the correct
order.
*/
TEST(deinterleave16, case1)
{

  int p_vals[] = {8, 4, 2, 1};

  for(int p = 0; p < 4; p++){

    uint32_t mask = 0xFFFFFFFF >> (32 - 2*p_vals[p]);

    for(int k = 0; k < CHAN_COUNT; k++){
      uint32_t vals[CHAN_COUNT] = {0};

      // only set the bits in the higher address words, which correspond to 
      // earlier samples.
      for(int n = CHAN_COUNT - p_vals[p]; n < CHAN_COUNT; n++)
        vals[n] = 0x00010001 << k;
      
      // printf("\n\n");
      // printf("Before:\n");
      // for(int n = 0; n < CHAN_COUNT/2; n++)
      //   printf("0x%08X, ", (unsigned) vals[n]);
      // printf("\n");
      // for(int n = CHAN_COUNT/2; n < CHAN_COUNT; n++)
      //   printf("0x%08X, ", (unsigned) vals[n]);
      // printf("\n\n");

      deinterleave16(&vals[0]);

      // printf("After:\n");
      // for(int n = 0; n < CHAN_COUNT/2; n++)
      //   printf("0x%08X, ", (unsigned) vals[n]);
      // printf("\n");
      // for(int n = CHAN_COUNT/2; n < CHAN_COUNT; n++)
      //   printf("0x%08X, ", (unsigned) vals[n]);
      // printf("\n\n");

      for(int n = 0; n < CHAN_COUNT; n++){
        uint32_t exp = (n == k) ? mask : 0x00000000;
        TEST_ASSERT_EQUAL_UINT32_MESSAGE(exp, vals[n], "");
      }

    }
  }
}

