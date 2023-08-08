// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <cstdint>
#include <string>
#include <cassert>
#include <iostream>
#include <type_traits>
#include <functional>

#include <xcore/channel.h>

// This has caused problems previously, so just catch the problems here.
#if defined(MIC_COUNT)
# error Application must not define the following as precompiler macros: MIC_COUNT.
#endif

using namespace std;

namespace  mic_array {

  /**
   * @brief SampleFilter which does nothing.
   * 
   * To be used as the `TSampleFilter` template parameter of @ref MicArray when
   * no post-decimation filtering is desired.
   * 
   * Calls to `NopSampleFilter::Filter()` are intended to be optimized out at
   * compile time.
   * 
   * @tparam MIC_COUNT  Number of microphone channels.
   */
  template<unsigned MIC_COUNT>
  class NopSampleFilter 
  {
    public:
      /**
       * @brief Do nothing.
       */
      void Filter(int32_t sample[MIC_COUNT]) {};
  };

  /**
   * @brief Filter which applies DC Offset Elimination (DCOE).
   * 
   * To be used as the `TSampleFilter` template parameter of @ref MicArray when
   * DCOE is desired as post-processing after the decimation filter.
   * 
   * The filter is a simple first-order IIR filter which applies the following
   * filter equation:
   * 
   * @code
   * R = 252.0 / 256.0
   * y[t] = R * y[t-1] + x[t] - x[t-1]
   * @endcode
   * 
   * @tparam MIC_COUNT  Number of microphone channels.
   */
  template<unsigned MIC_COUNT>
  class DcoeSampleFilter
  {

    protected:
      /**
       * @brief State of DCOE filters.
       */
      dcoe_chan_state_t state[MIC_COUNT];
    
    public:

      /**
       * @brief Initialize the filter states.
       * 
       * The filter states must be initialized prior to calls to `Filter()`.
       */
      void Init();

      /**
       * @brief Apply DCOE filter on samples.
       * 
       * `sample` is an array of samples to be filtered, and is updated 
       * in-place.
       * 
       * The filter states must have been initialized with a call to `Init()`
       * prior to calling this function.
       * 
       * @param sample Samples to be filtered. Updated in-place.
       */
      void Filter(int32_t sample[MIC_COUNT]);
  };
}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////


template <unsigned MIC_COUNT>
void mic_array::DcoeSampleFilter<MIC_COUNT>::Init()
{
  dcoe_state_init(&state[0], MIC_COUNT);
}


template <unsigned MIC_COUNT>
void mic_array::DcoeSampleFilter<MIC_COUNT>::Filter(
    int32_t sample[MIC_COUNT])
{
  dcoe_filter(&sample[0], &state[0], &sample[0], MIC_COUNT);
}