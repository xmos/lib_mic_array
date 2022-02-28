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

  template <unsigned MIC_COUNT, 
            unsigned S2_DEC_FACTOR, 
            unsigned S2_TAP_COUNT, 
            template <unsigned> class PdmRx_, 
            template <unsigned> class OutputSampleFilter_, 
            class OutputHandler_> 
  class MicArray 
  {
    public:
      static constexpr unsigned MicCount = MIC_COUNT;

      typedef PdmRx_<MIC_COUNT * S2_DEC_FACTOR> TPdmRx;
      typedef Decimator<MIC_COUNT, S2_DEC_FACTOR, S2_TAP_COUNT> TDecimator;
      typedef OutputHandler_ TOutputHandler;
      typedef OutputSampleFilter_<MIC_COUNT> TOutputSampleFilter;

    
      TPdmRx PdmRx;
      TDecimator Decimator;
      TOutputSampleFilter OutputSampleFilter;
      TOutputHandler OutputHandler;

    public:

      MicArray() { }

      MicArray(TPdmRx pdm_rx, 
               TOutputSampleFilter sample_filter,
               TOutputHandler output_handler) 
          : PdmRx(pdm_rx), 
            OutputSampleFilter(sample_filter), 
            OutputHandler(output_handler) { }

      MicArray(TPdmRx pdm_rx, 
               TOutputHandler output_handler)
        : MicArray(pdm_rx, TOutputSampleFilter(), output_handler) { }


      void ThreadEntry(){

        int32_t sample_out[MIC_COUNT] = {0};

        while(1){
          uint32_t* pdm_samples = PdmRx.GetPdmBlock();
          Decimator.ProcessBlock(sample_out, pdm_samples);
          OutputSampleFilter.Filter(sample_out);
          OutputHandler.OutputSample(sample_out);
        }
      }
  };

}
