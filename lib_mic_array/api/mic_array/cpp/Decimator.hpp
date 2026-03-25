// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <cstdint>
#include <string>
#include <cassert>

#include "xmath/xmath.h"
#include "mic_array/etc/fir_1x16_bit.h"

// This has caused problems previously, so just catch the problems here.
#if defined (MIC_COUNT)
# error Application must not define the following as precompiler macros: MIC_COUNT, S2_DEC_FACTOR.
#endif


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
 * @brief PDM Decimator (1, 2, or 3 stage)
 *
 * This class template represents a decimator which converts a stream
 * of PDM samples to a lower sample rate stream of PCM samples using
 * one, two, or three cascaded FIR decimation stages.
 *
 * Concrete implementations of this class template are meant to be used as the
 * `TDecimator` template parameter in the @ref MicArray class template.
 *
 * @tparam MIC_COUNT      Number of microphone channels.
 */
template <unsigned MIC_COUNT>
class Decimator
{
  private:

    /**
     * Stage 1 decimator configuration and state.
     */
    struct {
      /**
       * Pointer to filter coefficients for Stage 1
       */

      const uint32_t* filter_coef;
      /**
       * Pointer to filter state (PDM history) for stage-1 filter.
       */
      uint32_t *pdm_history_ptr;

      /**
       * Per-mic channel filter state (PDM history) size in 32-bit words for stage-1 filter.
       */
      unsigned pdm_history_sz;

      /**
       * Per-mic, 32-bit PDM output words from the PDM RX stage.
       */
      unsigned pdm_out_words_per_mic;
    } stage1;

  public:
    constexpr Decimator() noexcept { }

    /**
     * Stage 2 decimation configuration and state.
     */
    struct {
      /**
       * Stage 2 FIR filters
       */
      filter_fir_s32_t filters[MIC_COUNT];
      /**
       * Stage 2 filter decimation factor.
       */
      unsigned decimation_factor;
    } stage2;

    /**
     * Stage 3 decimation configuration and state.
     */
    struct {
      /**
       * Stage 3 FIR filters
       */
      filter_fir_s32_t filters[MIC_COUNT];
      /**
       * Stage 3 filter decimation factor.
       */
      unsigned decimation_factor;
    } stage3;

    /**
    * @brief Initialize the decimator from a configuration struct
     * @ref mic_array_decimator_conf_t @p decimator_conf
     *
    * Reads filter parameters for all configured stages from @p decimator_conf and prepares
    * internal state.
    * The caller must ensure all pointers inside @p decimator_conf.filter_conf[]
    * are valid and persist for the lifetime of the decimator.
     *
     * @param decimator_conf Decimator pipeline configuration.
     */
    void Init(mic_array_decimator_conf_t &decimator_conf, unsigned pdm_out_words_per_mic);

    /**
     * @brief Process one block of PDM data through the 2-stage decimator.
     *
     * Processes a block of PDM data to produce an output sample from the
     * second stage decimator.
     *
     * `pdm_block` contains exactly enough PDM samples to produce a single
     * output sample from the second stage decimator. The layout of `pdm_block`
     * should (effectively) be:
     *
     * @code{.cpp}
     *  struct {
     *    struct {
     *      // lower word indices are older samples.
     *      // less significant bits in a word are older samples.
     *      uint32_t samples[S2_DEC_FACTOR];
     *    } microphone[MIC_COUNT]; // mic channels are in ascending order
     *  } pdm_block;
     * @endcode
     *
     * A single output sample from the second stage decimator is computed and
     * written to `sample_out[]`.
     *
     * @param sample_out  Output sample vector.
     * @param pdm_block   PDM data to be processed.
     */
    void ProcessBlockTwoStage(
        int32_t sample_out[MIC_COUNT],
        uint32_t *pdm_block);

    /**
     * @brief Process one block of PDM data through only the 1st stage decimation filter.
     *
     * Consumes `pdm_out_words_per_mic` PDM words per microphone from `pdm_block`, runs the
     * stage-1 FIR, and produces `pdm_out_words_per_mic` PCM output samples per microphone.
     *
     * @param sample_out  Output sample array, written in [MIC_COUNT][pdm_out_words_per_mic] order.
     * @param pdm_block   Input PDM data, read in [MIC_COUNT][pdm_out_words_per_mic] order.
     */
    void ProcessBlockSingleStage(
        int32_t *sample_out,
        uint32_t *pdm_block);

    /**
     * @brief Process one block of PDM data through the 3-stage decimator.
     *
     * Consumes `stage2.decimation_factor * stage3.decimation_factor` PDM words per microphone
     * from `pdm_block`, runs the stage-1 FIR on each word, decimates through stage-2, then
     * stage-3, and produces one PCM output sample per microphone.
     *
     * @param sample_out  Output sample vector, one value per microphone channel.
     * @param pdm_block   Input PDM data, read in [MIC_COUNT][stage2.decimation_factor * stage3.decimation_factor] order.
     */
    void ProcessBlockThreeStage(
        int32_t sample_out[MIC_COUNT],
        uint32_t *pdm_block);

    /** Number of active decimation stages (1, 2, or 3). Set by @ref Init from
     *  `decimator_conf.num_filter_stages`. Determines which ProcessBlock variant
     *  should be called. */
    unsigned num_stages;

  };
}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////

template <unsigned MIC_COUNT>
void mic_array::Decimator<MIC_COUNT>
    ::Init(
        mic_array_decimator_conf_t &decimator_conf,
        unsigned pdm_out_words_per_mic)
{
  this->num_stages = decimator_conf.num_filter_stages;
  this->stage1.filter_coef = (const uint32_t*)decimator_conf.filter_conf[0].coef;
  this->stage1.pdm_history_ptr = (uint32_t*)decimator_conf.filter_conf[0].state;
  this->stage1.pdm_history_sz = decimator_conf.filter_conf[0].state_words_per_channel;
  this->stage1.pdm_out_words_per_mic = pdm_out_words_per_mic;

  memset(this->stage1.pdm_history_ptr, 0x55, sizeof(int32_t) * MIC_COUNT * this->stage1.pdm_history_sz);

  if(decimator_conf.num_filter_stages >= 2) {
    for(int k = 0; k < MIC_COUNT; k++){
      filter_fir_s32_init(&this->stage2.filters[k], decimator_conf.filter_conf[1].state + (k * decimator_conf.filter_conf[1].state_words_per_channel),
                          decimator_conf.filter_conf[1].num_taps, decimator_conf.filter_conf[1].coef, decimator_conf.filter_conf[1].shr);
    }
    this->stage2.decimation_factor = decimator_conf.filter_conf[1].decimation_factor;
  }

  if(decimator_conf.num_filter_stages == 3) {
    for(int k = 0; k < MIC_COUNT; k++){
      filter_fir_s32_init(&this->stage3.filters[k], decimator_conf.filter_conf[2].state + (k * decimator_conf.filter_conf[2].state_words_per_channel),
                          decimator_conf.filter_conf[2].num_taps, decimator_conf.filter_conf[2].coef, decimator_conf.filter_conf[2].shr);
    }
    this->stage3.decimation_factor = decimator_conf.filter_conf[2].decimation_factor;
  }
}


template <unsigned MIC_COUNT>
void mic_array::Decimator<MIC_COUNT>
    ::ProcessBlockTwoStage(
        int32_t sample_out[MIC_COUNT],
        uint32_t *pdm_block)
{
  for(unsigned mic = 0; mic < MIC_COUNT; mic++){
    uint32_t* hist = this->stage1.pdm_history_ptr + (mic * this->stage1.pdm_history_sz);

    for(unsigned k = 0; k < this->stage2.decimation_factor; k++){
      hist[0] = *(pdm_block + (mic*this->stage2.decimation_factor + k));
      int32_t streamA_sample = fir_1x16_bit(hist, this->stage1.filter_coef);
      shift_buffer(hist);

      if(k < (this->stage2.decimation_factor-1)){
        filter_fir_s32_add_sample(&this->stage2.filters[mic], streamA_sample);
      } else {
        sample_out[mic] = filter_fir_s32(&this->stage2.filters[mic], streamA_sample);
      }
    }
  }
}

template <unsigned MIC_COUNT>
void mic_array::Decimator<MIC_COUNT>
    ::ProcessBlockThreeStage(
        int32_t sample_out[MIC_COUNT],
        uint32_t *pdm_block)
{
  unsigned stage1_output_words = this->stage2.decimation_factor * this->stage3.decimation_factor;
  for(unsigned mic = 0; mic < MIC_COUNT; mic++){
    uint32_t* hist = this->stage1.pdm_history_ptr + (mic * this->stage1.pdm_history_sz);
    uint32_t* mic_base = pdm_block + (mic * stage1_output_words);
    int count2 = this->stage2.decimation_factor - 1;
    int count3 = this->stage3.decimation_factor - 1;
    for(unsigned k = 0; k < stage1_output_words; k++)
    {
      hist[0] = mic_base[k];

      int32_t streamA_sample = fir_1x16_bit(hist, this->stage1.filter_coef);
      shift_buffer(hist);

      if(count2) {
        filter_fir_s32_add_sample(&this->stage2.filters[mic], streamA_sample);
        count2 -= 1;
        continue;
      }
      int32_t streamB_sample = filter_fir_s32(&this->stage2.filters[mic], streamA_sample);
      count2 = this->stage2.decimation_factor - 1;
      if(count3) {
        filter_fir_s32_add_sample(&this->stage3.filters[mic], streamB_sample);
        count3 -= 1;
      }
      else {
        sample_out[mic] = filter_fir_s32(&this->stage3.filters[mic], streamB_sample);
        count3 = this->stage3.decimation_factor - 1;
      }
    }
  }
}

template <unsigned MIC_COUNT>
void mic_array::Decimator<MIC_COUNT>
    ::ProcessBlockSingleStage(
        int32_t *sample_out,
        uint32_t *pdm_block)
{
  // pdm_block expected to be in [MIC_COUNT][stage1.pdm_out_words_per_mic] format
  // sample_out is also updated in [MIC_COUNT][stage1.pdm_out_words_per_mic] format
  for(unsigned mic = 0; mic < MIC_COUNT; mic++) {
    uint32_t* hist = this->stage1.pdm_history_ptr + (mic * this->stage1.pdm_history_sz);
    for(unsigned k = 0; k < this->stage1.pdm_out_words_per_mic; k++) {
      hist[0] = *pdm_block++;
      *sample_out++ = fir_1x16_bit(hist, this->stage1.filter_coef);
      shift_buffer(hist);
    }
  }
}

static inline
void mic_array::shift_buffer(uint32_t* buff)
{
  #if defined(__XS3A__)
  uint32_t* src = &buff[-1];
  asm volatile("vldd %0[0]; vstd %1[0];" :: "r"(src), "r"(buff) : "memory" );
  #elif defined(__VX4B__)
  uint32_t* src = &buff[-1];
  asm volatile("xm.vldd %0; xm.vstd %1;" :: "r"(src), "r"(buff) : "memory" );
  #else // C fallback
  for (unsigned k = 7; k > 0; k--) {
    buff[k] = buff[k-1];
  }
  #endif
}
