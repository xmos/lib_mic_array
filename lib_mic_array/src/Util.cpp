// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "mic_array/cpp/Util.hpp"
#include "mic_array/util.h"

#include "mic_array.h"



template <>
void mic_array::deinterleave_pdm_samples<1>(
    uint32_t* samples,
    unsigned s2_dec_factor)
{
  //Nothing to do for 1 mic
}

template <>
void mic_array::deinterleave_pdm_samples<2>(
    uint32_t* samples,
    unsigned s2_dec_factor)
{
  constexpr unsigned MICS = 2;

  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*MICS];
    deinterleave2(sb);
  }
}

template <>
void mic_array::deinterleave_pdm_samples<4>(
    uint32_t* samples,
    unsigned s2_dec_factor)
{
  constexpr unsigned MICS = 4;

  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*MICS];
    deinterleave4(sb);
  }
}



template <>
void mic_array::deinterleave_pdm_samples<8>(
    uint32_t* samples,
    unsigned s2_dec_factor)
{
  constexpr unsigned MICS = 8;

  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*MICS];
    deinterleave8(sb);
  }
}

template <>
void mic_array::deinterleave_pdm_samples<16>(
    uint32_t* samples,
    unsigned s2_dec_factor)
{
  constexpr unsigned MICS = 16;

  for(int k = 0; k < s2_dec_factor; k++) {
    uint32_t* sb = &samples[k*MICS];
    deinterleave16(sb);
  }
}