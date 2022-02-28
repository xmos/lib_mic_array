#pragma once

#include "MicArray.hpp"
#include "mic_array/etc/filters_default.h"


namespace mic_array {
  namespace helper {

    using namespace mic_array;

    template <unsigned MIC_COUNT, unsigned FRAME_SIZE>
    class StandardMicArray 
        : public MicArray<MIC_COUNT, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                          StandardPdmRxService, DcoeSampleFilter,
                          FrameOutputHandler<MIC_COUNT, FRAME_SIZE, ChannelFrameTransfer>>
    {

      public:

        using TParent = MicArray<MIC_COUNT, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                          StandardPdmRxService, DcoeSampleFilter,
                          FrameOutputHandler<MIC_COUNT, FRAME_SIZE, ChannelFrameTransfer>>;

        StandardMicArray()
        {
          this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
        }

        StandardMicArray(
                typename TParent::TPdmRx pdm_rx, 
                typename TParent::TOutputHandler output_handler) 
            : TParent(pdm_rx, output_handler) 
            { 
              this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
            }

    };

  }
}