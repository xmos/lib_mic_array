#pragma once

#include <cstdint>
#include <string>
#include <cassert>
#include <iostream>
#include <type_traits>
#include <functional>

#include "mic_array.h"

#include <xcore/channel.h>

using namespace std;

namespace  mic_array {

  template<unsigned MIC_COUNT>
  class NopSampleFilter 
  {
    public:
      void Filter(int32_t sample[MIC_COUNT]) {};
  };

  template<unsigned MIC_COUNT>
  class DcoeSampleFilter
  {

    private:
      dcoe_chan_state_t state[MIC_COUNT];
    
    public:

      void Init()
      {
        dcoe_state_init(&state[0], MIC_COUNT);
      }

      void Filter(int32_t sample[MIC_COUNT])
      {
        dcoe_filter(&sample[0], &state[0], &sample[0], MIC_COUNT);
      }
  };


}
