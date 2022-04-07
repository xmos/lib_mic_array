#pragma once

#include <cstdint>
#include <string>
#include <cassert>
#include <iostream>
#include <type_traits>
#include <functional>

#include "mic_array/frame_transfer.h"

#include <xcore/channel.h>


// This has caused problems previously, so just catch the problems here.
#if defined(MIC_COUNT) || defined(SAMPLE_COUNT) || defined(FRAME_COUNT)
# error Application must not define the following as precompiler macros: MIC_COUNT, SAMPLE_COUNT, FRAME_COUNT.
#endif

using namespace std;

namespace  mic_array {

  /**
   * @brief OutputHandler which transmits samples over a channel.
   * 
   * This class is intended to be used as an OutputHandler with the `MicArray`
   * class.
   * 
   * With this class, each call to  `ProcessSample()` attempts to send the 
   * sample over a channel. The receiver must know how many channels to expect
   * and should waiting to receive the sample before `ProcessSample()` is called
   * on this object.
   * 
   * A sample is a vector quantity which corresponds to a single time step and
   * containing one element per audio channel.
   * 
   * @tparam MIC_COUNT Number of channels in a sample.
   */
  template <unsigned MIC_COUNT>
  class ChannelSampleTransmitter
  {
    private:

      /**
       * @brief Channel over which samples are transmitted.
       * 
       * This member can be set either by using the appropriate constructor or
       * with a call to `SetChannel()`. This channel must be set prior to any
       * calls to `ProcessSample()`.
       */
      chanend_t c_sample_out;

    public:

      /**
       * @brief Construct a `ChannelSampleTransmitter`.
       */
      ChannelSampleTransmitter() 
          : c_sample_out(0) { }

      /**
       * @brief Construct a `ChannelSampleTransmitter`.
       * 
       * @param c_sample_out Channel for sending samples.
       */
      ChannelSampleTransmitter(chanend_t c_sample_out)
          : c_sample_out(c_sample_out) { }

      /**
       * @brief Set the channel used for sending samples.
       * 
       * @param c_sample_out Channel for sending samples.
       */
      void SetChannel(chanend_t c_sample_out);

      /**
       * @brief Transmit the specified sample.
       * 
       * @param sample Sample to be transmitted.
       */
      void ProcessSample(int32_t sample[MIC_COUNT]);
  };



  /**
   * @brief OutputHandler for grouping samples into frames and sending frames
   *        to subsequent processing stages.
   * 
   * @tparam MIC_COUNT    Number of audio channels in each frame.
   * @tparam SAMPLE_COUNT Number of samples per frame.
   * @tparam FrameTransmitter
   * @tparam FRAME_COUNT  Number of frame buffers to rotate between.
   */
  template <unsigned MIC_COUNT, 
            unsigned SAMPLE_COUNT, 
            template <unsigned, unsigned> class FrameTransmitter,
            unsigned FRAME_COUNT = 1>
  class FrameOutputHandler
  {
    private:

      /**
       * @brief Index of the frame currently being filled.
       */
      unsigned current_frame = 0;

      /**
       * @brief Index of the sample currently being filled.
       */
      unsigned current_sample = 0;

      /**
       * @brief Frame buffers for transmitted frames.
       */
      int32_t frames[FRAME_COUNT][MIC_COUNT][SAMPLE_COUNT];

    public:

      /**
       * @brief `FrameTransmitter` used to transmit frames to the
       *        next stage for processing.
       */
      FrameTransmitter<MIC_COUNT, SAMPLE_COUNT> FrameTx;

    public:

      /**
       * @brief Construct new `FrameOutputHandler`.
       * 
       * The default no-argument constructor for `FrameTransmitter` is used to
       * create `FrameTx`.
       */
      FrameOutputHandler() { }

      /**
       * @brief Construct new `FrameOutputHandler`.
       * 
       * Uses the provided FrameTransmitter to send frames.
       * 
       * @param frame_tx Frame transmitter for sending frames.
       */
      FrameOutputHandler(FrameTransmitter<MIC_COUNT, SAMPLE_COUNT> frame_tx)
          : FrameTx(frame_tx) { }

      /**
       * @brief Add new sample to current frame and output frame if filled.
       * 
       * @param sample Sample to be added to current frame.
       */
      void OutputSample(int32_t sample[MIC_COUNT]);
  };


  /**
   * @brief Frame transmitter which transmits frame over a channel.
   * 
   * When using this frame transmitter, frames are transmitted over a channel
   * using the frame transfer API in `mic_array/frame_transfer.h`.
   * 
   * Usually, a call to `ma_frame_rx_s32()` (with the other end of `c_frame_out`
   * as argument) should be used to receive the frame on another thread.
   * 
   * Frames can be transmitted between tiles using this class.
   * 
   * @tparam MIC_COUNT    Number of audio channels in each frame.
   * @tparam SAMPLE_COUNT Number of samples per frame.
   */
  template <unsigned MIC_COUNT, unsigned SAMPLE_COUNT>
  class ChannelFrameTransmitter
  {
    private:

      /**
       * @brief Channel over which frames are transmitted.
       */
      chanend_t c_frame_out;

    public:

      /**
       * @brief Construct a `ChannelFrameTransmitter`.
       * 
       * If this constructor is used, `SetChannel()` must be used to configure 
       * the channel over which frames are transmitted prior to any calls to
       * `OutputFrame()`. 
       */
      ChannelFrameTransmitter() : c_frame_out(0) { }

      /**
       * @brief Construct a `ChannelFrameTransmitter`.
       * 
       * @param c_frame_out Channel over which frames are transmitted.
       */
      ChannelFrameTransmitter(chanend_t c_frame_out) : c_frame_out(c_frame_out) { }

      /**
       * @brief Set channel used for frame transfers.
       * 
       * @param c_frame_out Channel to be used for frame transfers.
       */
      void SetChannel(chanend_t c_frame_out);

      /**
       * @brief Get channel used for frame transfers.
       * 
       * @returns Channel to be used for frame transfers.
       */
      chanend_t GetChannel();

      /**
       * @brief Transmit the specified frame.
       * 
       * @param frame Frame to be transmitted.
       */
      void OutputFrame(int32_t frame[MIC_COUNT][SAMPLE_COUNT]);
  };
}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////


template <unsigned MIC_COUNT>
void mic_array::ChannelSampleTransmitter<MIC_COUNT>::SetChannel(
    chanend_t c_sample_out)
{
  this->c_sample_out = c_sample_out;
}


template <unsigned MIC_COUNT>
void mic_array::ChannelSampleTransmitter<MIC_COUNT>::ProcessSample(
    int32_t sample[MIC_COUNT])
{
  ma_frame_tx(this->c_sample_out, sample, MIC_COUNT, 1);
}



template <unsigned MIC_COUNT, 
          unsigned SAMPLE_COUNT, 
          template <unsigned, unsigned> class FrameTransmitter,
          unsigned FRAME_COUNT>
void mic_array::FrameOutputHandler<MIC_COUNT,SAMPLE_COUNT,
                        FrameTransmitter,FRAME_COUNT>::OutputSample(
    int32_t sample[MIC_COUNT])
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



template <unsigned MIC_COUNT, unsigned SAMPLE_COUNT>
void mic_array::ChannelFrameTransmitter<MIC_COUNT,SAMPLE_COUNT>::SetChannel(
    chanend_t c_frame_out)
{
  this->c_frame_out = c_frame_out;
}

template <unsigned MIC_COUNT, unsigned SAMPLE_COUNT>
chanend_t mic_array::ChannelFrameTransmitter<MIC_COUNT,SAMPLE_COUNT>::GetChannel()
{
  return this->c_frame_out;
}


template <unsigned MIC_COUNT, unsigned SAMPLE_COUNT>
void mic_array::ChannelFrameTransmitter<MIC_COUNT,SAMPLE_COUNT>::OutputFrame(
    int32_t frame[MIC_COUNT][SAMPLE_COUNT])
{
  ma_frame_tx(this->c_frame_out, 
                  reinterpret_cast<int32_t*>(frame), 
                  MIC_COUNT, SAMPLE_COUNT);
}