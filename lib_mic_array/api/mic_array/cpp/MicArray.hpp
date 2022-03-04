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



namespace  mic_array {

  /**
   * @brief Represents the microphone array component of an application.
   * 
   * @tparam MIC_COUNT    Number of microphones.
   * @tparam TDecimator   Type for the decimator.
   * @tparam TPdmRx       Type for the PDM rx service used.
   * @tparam TOutputSampleFilter Type for the output filter used.
   * @tparam TOutputHandler_Type for the output handler used.
   * 
   */
  template <unsigned MIC_COUNT,
            class TDecimator,
            class TPdmRx, 
            class TOutputSampleFilter, 
            class TOutputHandler> 
  class MicArray 
  {
    // @todo: Use static assertion to verify template parameters are of correct type

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
      TOutputSampleFilter OutputSampleFilter;

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
               TOutputSampleFilter sample_filter,
               TOutputHandler output_handler) 
          : PdmRx(pdm_rx), 
            OutputSampleFilter(sample_filter), 
            OutputHandler(output_handler) { }

      /**
       * @brief Construct a `MicArray`
       * 
       * @param pdm_rx
       * @param output_handler
       */
      MicArray(TPdmRx pdm_rx, 
               TOutputHandler output_handler)
        : MicArray(pdm_rx, TOutputSampleFilter(), output_handler) { }

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
          class TOutputSampleFilter, 
          class TOutputHandler> 
void mic_array::MicArray<MIC_COUNT,TDecimator,TPdmRx,
                                   TOutputSampleFilter,
                                   TOutputHandler>::ThreadEntry()
{
  int32_t sample_out[MIC_COUNT] = {0};

  while(1){
    uint32_t* pdm_samples = PdmRx.GetPdmBlock();
    Decimator.ProcessBlock(sample_out, pdm_samples);
    OutputSampleFilter.Filter(sample_out);
    OutputHandler.OutputSample(sample_out);
  }
}