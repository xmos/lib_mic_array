// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <cstdint>
#include <string>
#include <cassert>

#include "xmath/xmath.h"
#include "mic_array/etc/fir_1x16_bit.h"
#include "decimator_subtask.h"


// This has caused problems previously, so just catch the problems here.
#if defined(MIC_COUNT) || defined(S2_DEC_FACTOR) || defined(S2_TAP_COUNT)
# error Application must not define the following as precompiler macros: MIC_COUNT, S2_DEC_FACTOR, S2_TAP_COUNT.
#endif


namespace  par_mic_array {

/**
 * @brief First and Second Stage Decimator
 *
 * This class template represents a two stage decimator which converts a stream
 * of PDM samples to a lower sample rate stream of PCM samples.
 *
 * Concrete implementations of this class template are meant to be used as the
 * `TDecimator` template parameter in the @ref MicArray class template.
 *
 * @tparam MIC_COUNT      Number of microphone channels.
 * @tparam S2_DEC_FACTOR  Stage 2 decimation factor.
 * @tparam S2_TAP_COUNT   Stage 2 tap count.
 */
template <unsigned MIC_COUNT, unsigned S2_DEC_FACTOR, unsigned S2_TAP_COUNT>
class MyTwoStageDecimator
{

  public:
    /**
     * Size of a block of PDM data in words.
     */
    static constexpr unsigned BLOCK_SIZE = MIC_COUNT * S2_DEC_FACTOR;

    /**
     * Number of microphone channels.
     */
    static constexpr unsigned MicCount = MIC_COUNT;

    /**
     * Stage 2 decimator parameters
     */
    static const struct {
      /**
       * Stage 2 decimator decimation factor.
       */
      unsigned DecimationFactor = S2_DEC_FACTOR;
      /**
       * Stage 2 decimator tap count.
       */
      unsigned TapCount = S2_TAP_COUNT;
    } Stage2;

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
       * Filter state (PDM history) for stage 1 filters.
       */
      uint32_t pdm_history[MIC_COUNT][8]
#ifndef __DOXYGEN__ // doxygen breaks if it encounters this.
      // Must be initialized in this way. Initializing the history values in the
      // constructor causes an XCore-specific problem. Specifically, if the
      // MicArray instance where this decimator is used is declared outside of a
      // function scope (that is, as a global- or module-scope object; which it
      // ordinarily will be), initializing the PDM history within the
      // constructor forces the compiler to allocate the object on _all tiles_.
      // Being allocated on a tile where it is not used does not by itself break
      // anything, but it does result in less memory being available for other
      // things on that tile. Initializing the history in this way prevents
      // that.
        = {[0 ... (MIC_COUNT-1)] = { [0 ... 7] = 0x55555555 } }
#endif
      ;
    } stage1;

    /**
     * Stage 2 decimation configuration and state.
     */
    struct {
      /**
       * Stage 2 FIR filters
       */
      filter_fir_s32_t filters[MIC_COUNT];
      /**
       * Stage 2 filter stage.
       */
      int32_t filter_state[MIC_COUNT][S2_TAP_COUNT] = {{0}};
    } stage2;

  public:

    constexpr MyTwoStageDecimator() noexcept { }

    /**
     * @brief Initialize the decimator.
     *
     * Sets the stage 1 and 2 filter coefficients. The decimator must be
     * initialized before any calls to `ProcessBlock()`.
     *
     * `s1_filter_coef` points to a block of coefficients for the first stage
     * decimator. This library provides coefficients for the first stage
     * decimator; see `mic_array/etc/filters_default.h`.
     *
     * `s2_filter_coef` points to an array of coefficients for the second stage
     * decimator. This library provides coefficients for the second stage
     * decimator where the second stage decimation factor is 6; see
     * `mic_array/etc/filters_default.h`.
     *
     * `s2_filter_shr` is the final right-shift applied to the stage 2 filter's
     * accumulator prior to output. See
     * <a href="https://github.com/xmos/lib_xcore_math">lib_xcore_math's</a>
     * documentation of `filter_fir_s32_t` for more details.
     *
     * @param s1_filter_coef  @parblock
     *        Stage 1 filter coefficients.
     *
     *        This points to a block of coefficients for the first stage
     *        decimator. This library provides coefficients for the first stage
     *        decimator. \verbatim embed:rst
              See :c:var:`stage1_coef`.\endverbatim
     *        @endparblock
     * @param s2_filter_coef  @parblock
     *        Stage 2 filter coefficients.
     *
     *        This points to a block of coefficients for the second stage
     *        decimator. This library provides coefficients for the second stage
     *        decimator. \verbatim embed:rst
              See :c:var:`stage2_coef`.\endverbatim
     *        @endparblock
     * @param s2_filter_shr   @parblock
     *        Stage 2 filter right-shift.
     *
     *        This is the output shift used by the second stage decimator.
     *        \verbatim embed:rst
              See :c:var:`stage2_shr`.\endverbatim
     *        @endparblock
     */
    void Init(
        const uint32_t* s1_filter_coef,
        const int32_t* s2_filter_coef,
        const right_shift_t s2_filter_shr);

    /**
     * @brief Process one block of PDM data.
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
    void ProcessBlock(
        int32_t sample_out[MIC_COUNT],
        uint32_t pdm_block[BLOCK_SIZE]);
  };
}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////


template <unsigned MIC_COUNT, unsigned S2_DEC_FACTOR, unsigned S2_TAP_COUNT>
void par_mic_array::MyTwoStageDecimator<MIC_COUNT,S2_DEC_FACTOR,S2_TAP_COUNT>::Init(
    const uint32_t* s1_filter_coef,
    const int32_t* s2_filter_coef,
    const right_shift_t s2_shr)
{
  this->stage1.filter_coef = s1_filter_coef;

  for(int k = 0; k < MIC_COUNT; k++){
    filter_fir_s32_init(&this->stage2.filters[k], &this->stage2.filter_state[k][0],
                        S2_TAP_COUNT, s2_filter_coef, s2_shr);
  }
}



template <unsigned MIC_COUNT, unsigned S2_DEC_FACTOR, unsigned S2_TAP_COUNT>
void par_mic_array::MyTwoStageDecimator<MIC_COUNT,S2_DEC_FACTOR,S2_TAP_COUNT>
    ::ProcessBlock(
        int32_t sample_out[MIC_COUNT],
        uint32_t pdm_block[BLOCK_SIZE])
{
  decimator_subtask_run(MIC_COUNT,
    (uint32_t*)this->stage1.pdm_history, this->stage1.filter_coef,
    S2_DEC_FACTOR, this->stage2.filters,
    pdm_block, sample_out);
}
