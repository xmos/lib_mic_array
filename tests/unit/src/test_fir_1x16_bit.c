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
  RUN_TEST_CASE(fir_1x16_bit, with_stage1_coef);
  RUN_TEST_CASE(fir_1x16_bit, shift_buffer);
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
TEST(fir_1x16_bit, with_stage1_coef)
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
