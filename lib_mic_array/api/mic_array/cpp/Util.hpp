// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <cstdint>

namespace mic_array {

  /**
   * @brief Deinterleave the channels of a block of PDM data
   * 
   * PDM samples received on a port are shifted into a 32-bit buffer in such a 
   * way that the samples for each microphone channel are all interleaved with
   * one another.  The first stage decimator, however, requires these to be
   * separated.
   * 
   * `samples` must point to a buffer containing `(MIC_COUNT*s2_dec_factor)`
   * words of PDM data. Because the decimation factor for the first stage
   * decimator is a fixed value of `32`, `32` PDM samples from each microphone
   * is enough to produce one output sample (a `MIC_COUNT`-element vector) from
   * the first stage decimator. `32*s2_dec_factor` PDM samples for each of the
   * `MIC_COUNT` microphone channels is then exactly what is required to produce
   * a single output sample from the second stage decimator.
   * 
   * The PDM data will be deinterleaved in-place. 
   * 
   * @par Input Format
   * 
   * On input, the format of the buffer to which `samples` points is assumed to
   * be such that the following function will extract (only) the `k`th sample
   * for microphone channel `n` (where `k` is a time index, not a memory index):
   * 
   * @code{.c}
   *  unsigned get_sample(uint32_t* samples, 
   *                      unsigned MIC_COUNT, unsigned s2_dec_factor, 
   *                      unsigned n, unsigned k)
   *  {
   *    const end_word = MIC_COUNT * s2_dec_factor - 1; // chronologically first
   *    const unsigned samp_per_word = 32 / MIC_COUNT;
   *    const words_from_end = k / samp_per_word;
   *    const uint32_t word_val = samples[end_word-words_from_end];
   *    const unsigned bit_offset = (k % end_word) + n;
   *    return (word_val >> bit_offset) & 1;
   *  }
   * @endcode
   * 
   * Here, the words of `samples` are stored in reverse order (older samples are
   * at higher word indices), and within a word the oldest samples are the least
   * significant bits. The LSb of a word is always microphone channel `0`, and
   * the MSb of a word is always microphone channel `MIC_COUNT-1`.
   * 
   * @par Output Format
   * 
   * Upon return, the format of the buffer to which samples points will be such
   * that the following function will extract (only) the `k`th sample for
   * microphone channel `n`:
   * 
   * @code{.c}
   *  unsigned get_sample(uint32_t* samples, 
   *                      unsigned MIC_COUNT, unsigned s2_dec_factor, 
   *                      unsigned n, unsigned k)
   *  {
   *    const unsigned subblock = (s2_dec_factor-1)-(k/32);
   *    const unsigned word_val = samples[subblock * MIC_COUNT + n];
   *    return (word_val >> (k%32)) & 1;
   *  }
   * @endcode
   * 
   * Here, each word contains samples from only a single channel, with words at
   * higher addresses containing older samples. `samples[0]` contains the newest
   * samples for microphone channel `0`, and `samples[MIC_COUNT-1]` contains the
   * newest samples for microphone channel `MIC_COUNT-1`. `samples[MIC_COUNT]`
   * contains the next-oldest set of samples for channel `0`, and so on.
   * 
   * 
   * 
   * @tparam MIC_COUNT    Number of channels represented in PDM data.   
   *                      One of `{1,2,4,8}`
   * 
   * @param samples       Pointer to block of PDM samples.
   * @param s2_dec_factor Stage2 decimator decimation factor.
   */
  template <unsigned MIC_COUNT>
  void deinterleave_pdm_samples(
      uint32_t* samples,
      unsigned s2_dec_factor);


}