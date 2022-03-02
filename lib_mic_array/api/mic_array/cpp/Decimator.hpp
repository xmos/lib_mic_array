#pragma once

#include <cstdint>
#include <string>
#include <cassert>

#include "mic_array.h"
#include "xs3_math.h"
#include "mic_array/etc/fir_1x16_bit.h"

namespace  mic_array {

/**
 * @brief Rotate 8-word buffer 1 word up.
 * 
 * Each word `buff[k]` is moved to `buff[(k+1)%8]`.
 * 
 * @param buff  Word buffer to be rotated.
 */
static inline 
void shift_buffer(uint32_t* buff);

/**
 * @brief Deinterleave the channels of a block of PDM data
 * 
 * The block should contain `(MIC_COUNT * s2_dec_factor)` words of PDM data.
 * 
 * @tparam MIC_COUNT    Number of channels represented in PDM data.
 * 
 * @param samples       Pointer to block of samples
 * @param s2_dec_factor Stage2 decimator decimation factor
 */
template <unsigned MIC_COUNT>
static inline
void deinterleave_pdm_samples(
    uint32_t* samples,
    unsigned s2_dec_factor);


template <unsigned MIC_COUNT, unsigned S2_DEC_FACTOR, unsigned S2_TAP_COUNT>
class Decimator {

  static constexpr unsigned BLOCK_SIZE = MIC_COUNT * S2_DEC_FACTOR;

  public:

    static const unsigned MicCount = MIC_COUNT;

    static const struct {
      unsigned DecimationFactor = S2_DEC_FACTOR;
      unsigned TapCount = S2_TAP_COUNT;
    } Stage2;

  private:

    struct {
      uint32_t* filter_coef;
      uint32_t pdm_history[MIC_COUNT][8];
    } stage1;
    
    struct {
      xs3_filter_fir_s32_t filters[MIC_COUNT];
      int32_t filter_state[MIC_COUNT][S2_TAP_COUNT];
    } stage2;

  public:

    void Init(
        uint32_t* s1_filter_coef,
        const int32_t* s2_filter_coef,
        const right_shift_t s2_shr);

    void ProcessBlock(
        int32_t sample_out[MIC_COUNT],
        uint32_t pdm_block[BLOCK_SIZE]);
  };
}


template <unsigned MIC_COUNT, unsigned S2_DEC_FACTOR, unsigned S2_TAP_COUNT>
void mic_array::Decimator<MIC_COUNT,S2_DEC_FACTOR,S2_TAP_COUNT>::Init(
    uint32_t* s1_filter_coef,
    const int32_t* s2_filter_coef,
    const right_shift_t s2_shr) 
{      
  this->stage1.filter_coef = s1_filter_coef;
  
  std::memset(this->stage1.pdm_history, 0x55, sizeof(this->stage1.pdm_history));

  for(int k = 0; k < MIC_COUNT; k++){
    xs3_filter_fir_s32_init(&this->stage2.filters[k], &this->stage2.filter_state[k][0],
                            S2_TAP_COUNT, s2_filter_coef, s2_shr);
  }
}



template <unsigned MIC_COUNT, unsigned S2_DEC_FACTOR, unsigned S2_TAP_COUNT>
void mic_array::Decimator<MIC_COUNT,S2_DEC_FACTOR,S2_TAP_COUNT>::ProcessBlock(
        int32_t sample_out[MIC_COUNT],
        uint32_t pdm_block[BLOCK_SIZE])
{
  deinterleave_pdm_samples<MIC_COUNT>(&pdm_block[0], S2_DEC_FACTOR);

  for(unsigned mic = 0; mic < MIC_COUNT; mic++){
    uint32_t* hist = &this->stage1.pdm_history[mic][0];

    for(unsigned k = 0; k < S2_DEC_FACTOR; k++){
      int idx = (S2_DEC_FACTOR - 1 - k) * MIC_COUNT + mic;
      hist[0] = pdm_block[idx];
      int32_t streamA_sample = fir_1x16_bit(hist, this->stage1.filter_coef);

      shift_buffer(hist);

      if(k < (S2_DEC_FACTOR-1)){
        xs3_filter_fir_s32_add_sample(&this->stage2.filters[mic], streamA_sample);
      } else {
        sample_out[mic] = xs3_filter_fir_s32(&this->stage2.filters[mic], streamA_sample);
      }
    }
  }
}


static inline 
void mic_array::shift_buffer(uint32_t* buff)
{
  uint32_t* src = &buff[-1];
  asm volatile("vldd %0[0]; vstd %1[0];" :: "r"(src), "r"(buff) : "memory" );
}



template <>
static inline
void mic_array::deinterleave_pdm_samples<1>(
    uint32_t* samples,
    unsigned s2_dec_factor)
{
  //Nothing to do for 1 mic
}

template <>
static inline
void mic_array::deinterleave_pdm_samples<2>(
    uint32_t* samples,
    unsigned s2_dec_factor)
{
  for(int k = 0; k < s2_dec_factor; k++){
    asm volatile(
      "ldw r0, %0[1]      \n"
      "ldw r1, %0[0]      \n"
      "unzip r1, r0, 0    \n"
      "stw r0, %0[0]      \n"
      "stw r1, %0[1]        " :: "r"(samples) : "r0", "r1", "memory" );
    samples += 2;
  }
}