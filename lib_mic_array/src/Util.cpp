
#include "mic_array/cpp/Util.hpp"

#include "mic_array.h"

/**
 * Assembly function. 
 * 
 * Deinterleave the samples for 1 subblock of 2 microphones. Argument points to
 * a 2 word buffer.
 */
MA_C_API void deinterleave2(uint32_t*);
/**
 * Assembly function. 
 * 
 * Deinterleave the samples for 1 subblock of 4 microphones. Argument points to
 * a 4 word buffer.
 */
MA_C_API void deinterleave4(uint32_t*);
/**
 * Assembly function. 
 * 
 * Deinterleave the samples for 1 subblock of 8 microphones. Argument points to
 * a 8 word buffer.
 */
MA_C_API void deinterleave8(uint32_t*);



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