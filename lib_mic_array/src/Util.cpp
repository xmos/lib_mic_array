// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "mic_array/cpp/Util.hpp"
#include "mic_array/util.h"

#include "mic_array.h"



template <>
void mic_array::deinterleave_pdm_samples<1>(
    uint32_t* samples,
    unsigned s2_dec_factor,
    unsigned mic_in_count)
{
  //Nothing to do for 1 mic
}

template <>
void mic_array::deinterleave_pdm_samples<2>(
    uint32_t* samples,
    unsigned s2_dec_factor,
    unsigned mic_in_count)
{
  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*mic_in_count];
    deinterleave2(sb);
  }
}

template <>
void mic_array::deinterleave_pdm_samples<4>(
    uint32_t* samples,
    unsigned s2_dec_factor,
    unsigned mic_in_count)
{
  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*mic_in_count];
    deinterleave4(sb);
  }
}



template <>
void mic_array::deinterleave_pdm_samples<8>(
    uint32_t* samples,
    unsigned s2_dec_factor,
    unsigned mic_in_count)
{
  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*mic_in_count];
    deinterleave8(sb);
  }
}

template <>
void mic_array::deinterleave_pdm_samples<16>(
    uint32_t* samples,
    unsigned s2_dec_factor,
    unsigned mic_in_count)
{
  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*mic_in_count];
    deinterleave16(sb);
  }
}
