#pragma once

#include <type_traits>

#include "MicArray.hpp"
#include "mic_array/etc/filters_default.h"


namespace mic_array {
  namespace prefab {

    using namespace mic_array;

    template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE>
    class BasicMicArray 
        : public MicArray<MIC_COUNT, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                          StandardPdmRxService<MIC_COUNT * STAGE2_DEC_FACTOR>, 
                          typename std::conditional<USE_DCOE,
                                              DcoeSampleFilter<MIC_COUNT>,
                                              NopSampleFilter<MIC_COUNT>>::type,
                          FrameOutputHandler<MIC_COUNT, FRAME_SIZE, ChannelFrameTransfer>>
    {

      public:

        using TParent = MicArray<MIC_COUNT, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                          StandardPdmRxService<MIC_COUNT * STAGE2_DEC_FACTOR>, 
                          typename std::conditional<USE_DCOE,
                                              DcoeSampleFilter<MIC_COUNT>,
                                              NopSampleFilter<MIC_COUNT>>::type,
                          FrameOutputHandler<MIC_COUNT, FRAME_SIZE, ChannelFrameTransfer>>;

        BasicMicArray()
        {
          this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
        }

        BasicMicArray(
                typename TParent::TPdmRx pdm_rx, 
                typename TParent::TOutputHandler output_handler) 
            : TParent(pdm_rx, output_handler) 
        { 
          this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
        }

    };

  }
}