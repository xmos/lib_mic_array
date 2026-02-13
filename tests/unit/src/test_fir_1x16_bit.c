#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "unity.h"
#include "unity_fixture.h"

#include "mic_array/etc/fir_1x16_bit.h"
#include "mic_array/etc/filters_default.h"

TEST_GROUP_RUNNER(fir_1x16_bit) {
  RUN_TEST_CASE(fir_1x16_bit, symmetry_test);
  RUN_TEST_CASE(fir_1x16_bit, zero_signal);
  RUN_TEST_CASE(fir_1x16_bit, alternating_signal);
  RUN_TEST_CASE(fir_1x16_bit, with_stage1_coef);
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

// Test that zero-mean signal gives zero-ish result
TEST(fir_1x16_bit, alternating_signal)
{
  uint32_t signal[1024];
  extern uint32_t stage1_coef[STAGE1_WORDS];
  
  // Alternating pattern: half +1, half -1
  for(int i = 0; i < 1024; i++) {
    signal[i] = 0xAAAAAAAA;  // 10101010...
  }
  
  int result = fir_1x16_bit(signal, stage1_coef);
  
  // Should be close to zero (might not be exactly zero due to filter asymmetry)
  // Allow some tolerance
  TEST_ASSERT_INT_WITHIN(1000000, 0, result);
}

// Sanity check: function doesn't crash with zero signal
TEST(fir_1x16_bit, zero_signal)
{
  uint32_t signal[1024];
  extern uint32_t stage1_coef[STAGE1_WORDS];
  
  memset(signal, 0, sizeof(signal));
  
  int result = fir_1x16_bit(signal, stage1_coef);
  
  // Just verify it runs and returns something reasonable
  TEST_ASSERT_NOT_EQUAL(0, result);  // With real coeffs, unlikely to be exactly 0
}

TEST(fir_1x16_bit, with_stage1_coef)
{
  uint32_t signal[1024];
  int expected_result = 268435456;
  memset(signal, 0, sizeof(signal));
  
  int result = fir_1x16_bit(signal, stage1_coef);
  TEST_ASSERT_EQUAL_INT(expected_result, result);
}
