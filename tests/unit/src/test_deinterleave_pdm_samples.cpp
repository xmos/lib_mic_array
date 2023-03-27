// Copyright 2020-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>

#include "unity_fixture.h"

#include "mic_array/cpp/Util.hpp"

extern "C" {

TEST_GROUP_RUNNER(deinterleave_pdm_samples) {
  RUN_TEST_CASE(deinterleave_pdm_samples, interleave);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan1_sdf1);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan1_sdf3);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan1_sdf6);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan2_sdf1);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan2_sdf3);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan2_sdf6);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan4_sdf1);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan4_sdf4);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan4_sdf6);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan8_sdf1);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan8_sdf4);
  RUN_TEST_CASE(deinterleave_pdm_samples, chan8_sdf6);
}

TEST_GROUP(deinterleave_pdm_samples);
TEST_SETUP(deinterleave_pdm_samples) {}
TEST_TEAR_DOWN(deinterleave_pdm_samples) {}

}


template <unsigned CHAN_COUNT, unsigned BLOCKS>
void interleave_pdm_samples(uint32_t test_vect[], 
                            uint32_t expected[BLOCKS][CHAN_COUNT],
                            const uint32_t orig[CHAN_COUNT][BLOCKS])
{
  uint32_t copy[CHAN_COUNT][BLOCKS];
  memcpy(copy, orig, sizeof(copy));

  for(int b = 0; b < BLOCKS; b++){
    for(int c = 0; c < CHAN_COUNT; c++){
      expected[b][c] = orig[c][BLOCKS-1-b];
    }
  }

  for(int i = CHAN_COUNT*BLOCKS-1; i >= 0; i--){
    
    uint32_t& vect_word = test_vect[i];
    const unsigned b = BLOCKS - 1 - (i/CHAN_COUNT);

    for(int k = 0; k < 32; k++){
      const unsigned m = k % CHAN_COUNT;
      uint32_t& orig_word = copy[m][b];
      uint32_t a = orig_word & 1;
      orig_word = orig_word >> 1;
      vect_word = (vect_word >> 1) & 0x7FFFFFFF;
      vect_word = vect_word | (a * ((uint32_t)0x80000000));
    }
  }

}

extern "C" {
  
TEST(deinterleave_pdm_samples, interleave)
{
  if(1) {
    constexpr unsigned CHAN_COUNT = 1;
    constexpr unsigned BLOCKS = 1;
    constexpr unsigned WORD_COUNT = CHAN_COUNT * BLOCKS;

    uint32_t original[CHAN_COUNT][BLOCKS] = {{ 0x12345678 }};
    uint32_t exp_expected[BLOCKS][CHAN_COUNT] = {{ 0x12345678 }};
    uint32_t exp_test_vect[BLOCKS][CHAN_COUNT] = {{ 0x12345678 }};

    uint32_t expected[BLOCKS][CHAN_COUNT];
    uint32_t test_vect[BLOCKS][CHAN_COUNT];

    interleave_pdm_samples<CHAN_COUNT,BLOCKS>(&test_vect[0][0], expected, original);

    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_expected[0][0], &expected[0][0], WORD_COUNT);
    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_test_vect[0][0], &test_vect[0][0], WORD_COUNT);
  }

  if(1) {
    constexpr unsigned CHAN_COUNT = 2;
    constexpr unsigned BLOCKS = 1;
    constexpr unsigned WORD_COUNT = CHAN_COUNT * BLOCKS;

    uint32_t original[CHAN_COUNT][BLOCKS] = {{0x01234567},{0x89ABCDEF}};
    uint32_t exp_expected[BLOCKS][CHAN_COUNT] = {{0x01234567, 0x89ABCDEF}};
    uint32_t exp_test_vect[BLOCKS][CHAN_COUNT] = {{ 0x80838C8F, 0xB0B3BCBF }};

    uint32_t expected[BLOCKS][CHAN_COUNT];
    uint32_t test_vect[BLOCKS][CHAN_COUNT];

    interleave_pdm_samples<CHAN_COUNT,BLOCKS>(&test_vect[0][0], expected, original);

    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_expected[0][0], &expected[0][0], WORD_COUNT);
    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_test_vect[0][0], &test_vect[0][0], WORD_COUNT);
  }
  
  if(1) {
    constexpr unsigned CHAN_COUNT = 1;
    constexpr unsigned BLOCKS = 2;
    constexpr unsigned WORD_COUNT = CHAN_COUNT * BLOCKS;

    uint32_t original[CHAN_COUNT][BLOCKS] = {{ 0x01234567, 0x89ABCDEF }};
    uint32_t exp_expected[BLOCKS][CHAN_COUNT] = {{0x89ABCDEF}, {0x01234567}};
    uint32_t exp_test_vect[BLOCKS][CHAN_COUNT] = {{0x89ABCDEF},{0x01234567}};

    uint32_t expected[BLOCKS][CHAN_COUNT];
    uint32_t test_vect[BLOCKS][CHAN_COUNT];

    interleave_pdm_samples<CHAN_COUNT,BLOCKS>(&test_vect[0][0], expected, original);

    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_expected[0][0], &expected[0][0], WORD_COUNT);
    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_test_vect[0][0], &test_vect[0][0], WORD_COUNT);
  }

  if(1) {
    constexpr unsigned CHAN_COUNT = 2;
    constexpr unsigned BLOCKS = 2;
    constexpr unsigned WORD_COUNT = CHAN_COUNT * BLOCKS;

    uint32_t original[CHAN_COUNT][BLOCKS] =      {{0x01234567,0xFF00FF00},
                                                  {0x89ABCDEF,0x00FF00FF}};
    uint32_t exp_expected[BLOCKS][CHAN_COUNT] =  {{0xFF00FF00,0x00FF00FF},
                                                  {0x01234567,0x89ABCDEF}};
    uint32_t exp_test_vect[BLOCKS][CHAN_COUNT] = {{0x5555AAAA,0x5555AAAA},
                                                  {0x80838C8F,0xB0B3BCBF}};

    uint32_t expected[BLOCKS][CHAN_COUNT];
    uint32_t test_vect[BLOCKS][CHAN_COUNT];

    interleave_pdm_samples<CHAN_COUNT,BLOCKS>(&test_vect[0][0], expected, original);

    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_expected[0][0], &expected[0][0], WORD_COUNT);
    TEST_ASSERT_EQUAL_UINT32_ARRAY(&exp_test_vect[0][0], &test_vect[0][0], WORD_COUNT);
  }
}

}

template <unsigned CHAN_COUNT, unsigned BLOCKS>
static
void test_deinterleave_pdm_samples()
{

  uint32_t original[CHAN_COUNT][BLOCKS];
  uint32_t expected[BLOCKS][CHAN_COUNT];
  uint32_t test_vect[BLOCKS][CHAN_COUNT];

  srand((CHAN_COUNT+97)*(BLOCKS*57)+0x5463);

  static constexpr unsigned LOOP_COUNT = 4000;

  for(int r = 0; r < LOOP_COUNT; r++){

    for(int c = 0; c < CHAN_COUNT; c++)
      for(int b = 0; b < BLOCKS; b++)
        original[c][b] = rand();

    interleave_pdm_samples<CHAN_COUNT,BLOCKS>(&test_vect[0][0], expected, original);

    mic_array::deinterleave_pdm_samples<CHAN_COUNT>(&test_vect[0][0], BLOCKS);

    TEST_ASSERT_EQUAL_UINT32_ARRAY(&expected[0][0], &test_vect[0][0], 
                                    CHAN_COUNT * BLOCKS);
  }
}

extern "C" {

TEST(deinterleave_pdm_samples, chan1_sdf1) { test_deinterleave_pdm_samples<1,1>(); }
TEST(deinterleave_pdm_samples, chan1_sdf3) { test_deinterleave_pdm_samples<1,3>(); }
TEST(deinterleave_pdm_samples, chan1_sdf6) { test_deinterleave_pdm_samples<1,6>(); }
TEST(deinterleave_pdm_samples, chan2_sdf1) { test_deinterleave_pdm_samples<2,1>(); }
TEST(deinterleave_pdm_samples, chan2_sdf3) { test_deinterleave_pdm_samples<2,3>(); }
TEST(deinterleave_pdm_samples, chan2_sdf6) { test_deinterleave_pdm_samples<2,6>(); }
TEST(deinterleave_pdm_samples, chan4_sdf1) { test_deinterleave_pdm_samples<4,1>(); }
TEST(deinterleave_pdm_samples, chan4_sdf4) { test_deinterleave_pdm_samples<4,4>(); }
TEST(deinterleave_pdm_samples, chan4_sdf6) { test_deinterleave_pdm_samples<4,6>(); }
TEST(deinterleave_pdm_samples, chan8_sdf1) { test_deinterleave_pdm_samples<8,1>(); }
TEST(deinterleave_pdm_samples, chan8_sdf4) { test_deinterleave_pdm_samples<8,4>(); }
TEST(deinterleave_pdm_samples, chan8_sdf6) { test_deinterleave_pdm_samples<8,6>(); }



}