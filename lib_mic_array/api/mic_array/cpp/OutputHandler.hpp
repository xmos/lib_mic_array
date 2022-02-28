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

  template <unsigned MIC_COUNT>
  class ChannelSampleTransfer
  {
    private:

      chanend_t c_sample_out;

    public:

      ChannelSampleTransfer() 
          : c_sample_out(0) { }

      ChannelSampleTransfer(chanend_t c_sample_out)
          : c_sample_out(c_sample_out) { }

      void SetChannel(chanend_t c_sample_out)
      {
        this->c_sample_out = c_sample_out;
      }

      void ProcessSample(int32_t sample[MIC_COUNT])
      {
        for(int k = 0; k < MIC_COUNT; k++)
          chan_out_word(this->c_sample_out, sample[k]);
      }
  };



  template <unsigned MIC_COUNT, 
            unsigned SAMPLE_COUNT, 
            template <unsigned, unsigned> class FrameTransmitter,
            unsigned FRAME_COUNT = 1>
  class FrameOutputHandler
  {
    private:

      unsigned current_frame = 0;
      unsigned current_sample = 0;

      int32_t frames[FRAME_COUNT][MIC_COUNT][SAMPLE_COUNT];

    public:

      FrameTransmitter<MIC_COUNT, SAMPLE_COUNT> FrameTx;

    public:

      FrameOutputHandler() { }
      
      FrameOutputHandler(FrameTransmitter<MIC_COUNT, SAMPLE_COUNT> frame_tx)
          : FrameTx(frame_tx) { }

      void OutputSample(int32_t sample[MIC_COUNT])
      {
        auto* cur_frame = reinterpret_cast<int32_t (*)[SAMPLE_COUNT]>(
                              &this->frames[this->current_frame][0][0]);
        
        for(int k = 0; k < MIC_COUNT; k++) 
          cur_frame[k][this->current_sample] = sample[k];
        
        if(++current_sample == SAMPLE_COUNT){
          current_sample = 0;
          current_frame++;
          if(current_frame == FRAME_COUNT) current_frame = 0;

          FrameTx.OutputFrame( cur_frame );
        }
      }
  };


  template <unsigned MIC_COUNT, unsigned SAMPLE_COUNT>
  class ChannelFrameTransfer
  {
    private:

      chanend_t c_frame_out;
      const ma_frame_format_t format 
              = ma_frame_format(MIC_COUNT, 
                                SAMPLE_COUNT, 
                                MA_LYT_CHANNEL_SAMPLE);

    public:

      ChannelFrameTransfer() : c_frame_out(0) { }
      ChannelFrameTransfer(chanend_t c_frame_out) : c_frame_out(c_frame_out) { }

      void SetChannel(chanend_t c_frame_out)
      {
        this->c_frame_out = c_frame_out;
      }

      void OutputFrame(int32_t frame[MIC_COUNT][SAMPLE_COUNT])
      {
        ma_frame_tx_s32(this->c_frame_out, reinterpret_cast<int32_t*>(frame), &this->format);
      }
  };
}
