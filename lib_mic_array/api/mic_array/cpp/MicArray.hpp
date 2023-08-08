// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

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
   * \verbatim embed:rst
     Like many classes in this library, `FrameOutputHandler` uses the :ref:`crtp`.\endverbatim
   * 
   * @tparam MIC_COUNT @parblock
   * The number of microphones to be *captured* by the `MicArray`'s `PdmRx`
   * component. For example, if using a 4-bit port to capture 6 microphone
   * channels in a DDR configuration (because there are no 3 or 6 pin ports)
   * `MIC_COUNT` should be ``8``, because that's how many must be captured,
   * even if two of them are stripped out before passing audio frames to
   * subsequent application stages.
   * @endparblock
   * 
   * @tparam TDecimator     Type for the decimator. See @ref Decimator.
   * @tparam TPdmRx         Type for the PDM rx service used. See @ref PdmRx.
   * @tparam TSampleFilter  Type for the output filter used. See @ref SampleFilter.
   * @tparam TOutputHandler Type for the output handler used. See @ref OutputHandler.
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
       * The template parameter `TPdmRx` is the concrete class implementing the
       * microphone array's PDM rx service, which is responsible for collecting
       * PDM samples from a port and delivering them to the decimation thread.
       * 
       * `TPdmRx` is only required to implement one function, `GetPdmBlock()`:
       * @code {.cpp}
       * uint32_t* GetPdmBlock();
       * @endcode
       * 
       * `GetPdmBlock()` returns a pointer to a block of PDM data, formatted as
       * expected by the decimator. `GetPdmBlock()` is called *from the
       * decimator thread* and is expected to block until a new full block of
       * PDM data is available to be decimated.
       * 
       * For example, @ref StandardPdmRxService::GetPdmBlock() waits to receive
       * a pointer to a block of PDM data from a streaming channel. The pointer
       * is sent from the PdmRx interrupt (or thread) when the block has been
       * completed. This is used for capturing PDM data from a port.
       */
      TPdmRx PdmRx;

      /**
       * @brief The Decimator.
       * 
       * The template parameter `TDecimator` is the concrete class implementing
       * the microphone array's decimation procedure. `TDecimator` is only
       * required to implement one function, `ProcessBlock()`:
       * @code{.cpp}
       * void ProcessBlock(
       *     int32_t sample_out[MIC_COUNT],
       *     uint32_t pdm_block[BLOCK_SIZE]);
       * @endcode
       * 
       * `ProcessBlock()` takes a block of PDM samples via its `pdm_block`
       * parameter, applies the appropriate decimation logic, and outputs a
       * single (multi-channel) sample sample via its `sample_out` parameter.
       * The size and formatting of the PDM block expected by the decimator
       * depends on its particular implementation.
       * 
       * A concrete class based on the @ref mic_array::TwoStageDecimator class
       * template is used in the @ref prefab::BasicMicArray prefab.
       */
      TDecimator Decimator;

      /**
       * @brief The output filter.
       * 
       * The template parameter `TSampleFilter` is the concrete class
       * implementing the microphone array's sample filter component. This
       * component can be used to apply additional non-decimating,
       * non-interpolating filtering of samples. `TSampleFilter()` is only
       * required to implement one function, `Filter()`:
       * @code{.cpp}
       * void Filter(int32_t sample[MIC_COUNT]);
       * @endcode
       * 
       * `Filter()` takes a single (multi-channel) sample from the decimator
       * component's output and may update the sample in-place.
       * 
       * For example a sample filter based on the @ref DcoeSampleFilter class
       * template applies a simple first-order IIR filter to the output of the
       * decimator, in order to eliminate the DC component of the audio signals.
       * 
       * If no additional filtering is required, the @ref NopSampleFilter class
       * template can be used for `TSampleFilter`, which leaves the sample
       * unmodified. In this case, it is expected that the call to 
       * @ref NopSampleFilter::Filter() will ultimately get completely
       * eliminated at build time. That way no addition run-time compute or
       * memory costs need be introduced for the additional flexibility.
       * 
       * Even though `TDecimator` and `TSampleFilter` both (possibly) apply
       * filtering, they are separate components of the `MicArray` because they
       * are conceptually independent.
       * 
       * A concrete class based on either the @ref DcoeSampleFilter class
       * template or the @ref NopSampleFilter class template is used in the 
       * @ref prefab::BasicMicArray prefab, depending on the
       * `USE_DCOE` parameter of that class template.
       */
      TSampleFilter SampleFilter;

      /**
       * @brief The output handler.
       *    
       * The template parameter `TOutputHandler` is the concrete class
       * implementing the microphone array's output handler component. After the
       * PDM input stream has been decimated to the appropriate output sample
       * rate, and after any post-processing of that output stream by the sample
       * filter, the output samples must be delivered to another thread for any
       * additional processing. It is the responsibility of this component to
       * package and deliver audio samples to subsequent processing stages.
       * 
       * `TOutputHandler` is only required to implement one function,
       * `OutputSample()`:
       * @code{.cpp}
       * void OutputSample(int32_t sample[MIC_COUNT]);
       * @endcode
       * 
       * `OutputSample()` is called exactly once for each mic array output
       * sample. `OutputSample()` may block if necessary until the subsequent
       * processing stage ready to receive new data. However, the decimator
       * thread (in which `OutputSample()` is called) as a whole has a real-time
       * constraint - it must be ready to pull the next block of PDM data while
       * it is available.
       * 
       * A concrete class based on the @ref FrameOutputHandler class template is
       * used in the @ref prefab::BasicMicArray prefab.
       */
      TOutputHandler OutputHandler;

    public:

      /**
       * @brief Construct a `MicArray`.
       * 
       * This constructor uses the default constructor for each of its
       * components, @ref PdmRx, @ref Decimator, @ref SampleFilter, 
       * and @ref OutputHandler.
       */
      MicArray() { }

      /**
       * @brief Construct a `MicArray`.
       * 
       * This constructor uses the default constructor for its 
       * @ref Decimator component.
       * 
       * The remaining components are initialized with the supplied objects.
       * 
       * @param pdm_rx          The PDM rx object.
       * @param sample_filter   The SampleFilter object.
       * @param output_handler  The OutputHandler object.
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
       * This constructor uses the default constructor for its 
       * @ref Decimator and @ref SampleFilter components.
       * 
       * The remaining components are initialized with the supplied objects.
       * 
       * @param pdm_rx          The PDM rx object.
       * @param output_handler  The OutputHandler object.
       */
      MicArray(TPdmRx pdm_rx, 
               TOutputHandler output_handler)
        : MicArray(pdm_rx, TSampleFilter(), output_handler) { }

      /**
       * @brief Entry point for the decimation thread.
       * 
       * This function does not return. It loops indefinitely, collecting blocks
       * of PDM data from @ref PdmRx (which must have already been started),
       * uses @ref Decimator to filter and decimate the sample stream to the
       * output sample rate, applies any post-processing with @ref SampleFilter,
       * and then delivers the stream of output samples through @ref
       * OutputHandler.
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