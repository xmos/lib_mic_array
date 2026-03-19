// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <xcore/hwtimer.h>

#include "unity.h"
#include "unity_fixture.h"

#include "mic_array/etc/fir_1x16_bit.h"
#include "mic_array/etc/filters_default.h"

TEST_GROUP_RUNNER(fir_1x16_bit) {
  RUN_TEST_CASE(fir_1x16_bit, symmetry_test);
  RUN_TEST_CASE(fir_1x16_bit, single_val);
  RUN_TEST_CASE(fir_1x16_bit, random_test);
}

TEST_GROUP(fir_1x16_bit);
TEST_SETUP(fir_1x16_bit) {}
TEST_TEAR_DOWN(fir_1x16_bit) {}

// Test that opposite signals produce opposite results
TEST(fir_1x16_bit, symmetry_test)
{
  uint32_t signal_pos[1024];
  uint32_t signal_neg[1024];
  
  // Using real stage 1 coefficients
  extern uint32_t stage1_coef[STAGE1_WORDS];
  
  memset(signal_pos, 0x00, sizeof(signal_pos));  // All +1
  memset(signal_neg, 0xFF, sizeof(signal_neg));  // All -1
  
  int result_pos = fir_1x16_bit(signal_pos, stage1_coef);
  int result_neg = fir_1x16_bit(signal_neg, stage1_coef);
  
  // Opposite signals should give opposite results
  TEST_ASSERT_EQUAL_INT(-result_pos, result_neg);
}

// Test zero signal with known inputs/outputs
TEST(fir_1x16_bit, single_val)
{
  const int expected_result = 268435456; 
  const unsigned max_cycles = 35;

  unsigned elapsed = 0;
  int result = -1;
  uint32_t signal[1024];
  memset(signal, 0, sizeof(signal));
  
  elapsed = get_reference_time();
  result = fir_1x16_bit(signal, stage1_coef);
  elapsed = get_reference_time() - elapsed;

  TEST_ASSERT_EQUAL_INT(expected_result, result);
  TEST_ASSERT_LESS_OR_EQUAL(max_cycles, elapsed);
}

TEST(fir_1x16_bit, random_test)
{
  #define n_vpu 16
  #define sig_len (n_vpu * 20)
  #define PRINT_OUT (1)

  const int sig_exp[n_vpu] = {
    -58529792,34287616,70240256,17392640,52816384,
    -51980800,54905856,40349696,-60945408,14667776,
    -3800064,33825280,-1670656,879616,-23246848,-11620864,
  };

  uint32_t sig_in[sig_len] = {0};
  int sig_out[n_vpu] = {0};

  // seed
  srand(12345);
  for (unsigned i = 0; i < sig_len; i++)
  {
    sig_in[i] = rand() & 0xFFFFFFFF; // Random 32-bit word
  }

  // Using real stage 1 coefficients
  for (unsigned i = 0; i < n_vpu; i++)
  {
    uint32_t *sig_ptr = &sig_in[i * 20]; // 20 words per VPU block
    sig_out[i] = fir_1x16_bit(sig_ptr, stage1_coef);
  }

  #if PRINT_OUT
  printf("\nExpected vs Actual:\n");
  for (unsigned i = 0; i < n_vpu; i++)
  {
    printf("sig_out[%u] = %d, sig_exp = %d\n", i, sig_out[i], sig_exp[i]);
  }
  #endif

  TEST_ASSERT_EQUAL_INT_ARRAY(sig_exp, sig_out, n_vpu);
}
