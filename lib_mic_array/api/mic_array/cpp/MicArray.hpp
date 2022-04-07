#pragma once

#include <cstdint>
#include <string>
#include <cassert>
#include <cstdio>
#include <type_traits>
#include <functional>

#include "PdmRx.hpp"
#include "Decimator.hpp"
#include "SampleFilter.hpp"
#include "OutputHandler.hpp"

#include "mic_array.h"

#include <xcore/channel.h>

using namespace std;

// This has caused problems previously, so just catch the problems here.
#if defined(MIC_COUNT)
# error Application must not define the following as precompiler macros: MIC_COUNT.
#endif


namespace  mic_array {

  /**
   * @brief Represents the microphone array component of an application.
   * 
   * @tparam MIC_COUNT      Number of microphones.
   * @tparam TDecimator     Type for the decimator.
   * @tparam TPdmRx         Type for the PDM rx service used.
   * @tparam TSampleFilter  Type for the output filter used.
   * @tparam TOutputHandler Type for the output handler used.
   * 
   */
  template <unsigned MIC_COUNT,
            class TDecimator,
            class TPdmRx, 
            class TSampleFilter, 
            class TOutputHandler> 
  class MicArray 
  {

    public:

      /**
       * @brief Number of microphone channels.
       */
      static constexpr unsigned MicCount = MIC_COUNT;


      /**
       * @brief The PDM rx service.
       * 
       * This is used for capturing PDM data from a port.
       */
      TPdmRx PdmRx;

      /**
       * @brief The Decimator.
       * 
       * This two-stage decimator is used to convert and down-sample the
       * PDM stream into a PCM stream.
       */
      TDecimator Decimator;

      /**
       * @brief The output filter.
       * 
       * This is used to perform sample-by-sample filtering of the output from
       * the second stage decimator.
       */
      TSampleFilter SampleFilter;

      /**
       * @brief The output handler.
       * 
       * This is used to transmit samples or frames to subsequent stages of the
       * processing pipeline.
       */
      TOutputHandler OutputHandler;

    public:

      /**
       * @brief Construct a `MicArray`.
       */
      MicArray() { }

      /**
       * @brief Construct a `MicArray`.
       * 
       * @param pdm_rx
       * @param sample_filter
       * @param output_handler
       */
      MicArray(TPdmRx pdm_rx, 
               TSampleFilter sample_filter,
               TOutputHandler output_handler) 
          : PdmRx(pdm_rx), 
            SampleFilter(sample_filter), 
            OutputHandler(output_handler) { }

      /**
       * @brief Construct a `MicArray`
       * 
       * @param pdm_rx
       * @param output_handler
       */
      MicArray(TPdmRx pdm_rx, 
               TOutputHandler output_handler)
        : MicArray(pdm_rx, TSampleFilter(), output_handler) { }

      /**
       * @brief Entry point for the decimation thread.
       */
      void ThreadEntry();
  };

}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////



template <unsigned MIC_COUNT, 
          class TDecimator,
          class TPdmRx, 
          class TSampleFilter, 
          class TOutputHandler> 
void mic_array::MicArray<MIC_COUNT,TDecimator,TPdmRx,
                                   TSampleFilter,
                                   TOutputHandler>::ThreadEntry()
{
  int32_t sample_out[MIC_COUNT] = {0};

  while(1){
    uint32_t* pdm_samples = PdmRx.GetPdmBlock();
    Decimator.ProcessBlock(sample_out, pdm_samples);
    SampleFilter.Filter(sample_out);
    OutputHandler.OutputSample(sample_out);
  }
}