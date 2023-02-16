// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

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
   * @brief OutputHandler implementation which groups samples into
   *        non-overlapping multi-sample audio frames and sends entire frames to
   *        subsequent processing stages.
   * 
   * This class template can be used as an OutputHandler with the @ref MicArray
   * class template. See @ref MicArray::OutputHandler.
   * 
   * Classes derived from this template collect samples into frames. A frame
   * is a 2 dimensional array with one index corresponding to the audio channel
   * and the other index corresponding to time step, e.g.:
   * 
   * @code{.c}
   * int32_t frame[MIC_COUNT][SAMPLE_COUNT];
   * @endcode
   * 
   * Each call to @ref OutputSample() adds the sample to the current frame, and
   * then iff the frame is full, uses its @ref FrameTx component to transfer the
   * frame of audio to subsequent processing stages. Only one of every
   * `SAMPLE_COUNT` calls to @ref OutputSample() results in an actual
   * transmission to subsequent stages.
   * 
   * With `FrameOutputHandler`, the thread receiving the audio will generally
   * need to know how many microphone channels and how many samples to expect
   * per frame (although, strictly speaking, that depends upon the chosen
   * `FrameTransmitter` implementation).
   * 
   * @tparam MIC_COUNT @parblock
   * The number of audio channels in each sample and each frame.
   * @endparblock
   * 
   * @tparam SAMPLE_COUNT Number of samples per frame. @parblock
   * The `SAMPLE_COUNT` template parameter is the number of samples assembled
   * into each audio frame. Only completed frames are transmitted to subsequent
   * processing stages. A `SAMPLE_COUNT` value of `1` effectively disables 
   * framing, transmitting one sample for each call made to @ref OutputSample.
   * @endparblock
   * 
   * @tparam FrameTransmitter @parblock
   * The concrete type of the @ref FrameTx component of this class.
   * \verbatim embed:rst
     Like many classes in this library, `FrameOutputHandler` uses the :ref:`crtp`.
     \endverbatim
   * @endparblock
   * 
   * @tparam FRAME_COUNT @parblock
   * The number of frame buffers an instance of `FrameOutputHandler` should
   * cycle through. Unless audio frames are communicated with subsequent
   * processing stages through shared memory, the default value of `1` is usualy
   * ideal.
   * @endparblock
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
       * 
       * `FrameTransmitter` is the CRTP type template parameter used in this
       * class to control how frames of audio data are communicated with
       * subsequent pipeline stages.
       * 
       * The type supplied for `FrameTransmitter` must be a class template with
       * two integer template parameters, corresponding to this class's
       * `MIC_COUNT` and `SAMPLE_COUNT` template parameters respectively,
       * indicating the shape of the frame object to be transmitted.
       * 
       * The `FrameTransmitter` type is required to implement a single method:
       * 
       * @code{.cpp}
       * void OutputFrame(int32_t frame[MIC_COUNT][SAMPLE_COUNT]);
       * @endcode
       * 
       * `OutputFrame()` is called once for each completed audio frame and is
       * responsible for the details of how the frame's data gets communicated
       * to subsequent stages. For example, the @ref ChannelFrameTransmitter
       * class template uses an XCore channel to send samples to another thread
       * (by value). 
       * 
       * Alternative implementations might use shared memory or an RTOS queue to
       * transmit the frame data, or might even use a port to signal the samples
       * directly to an external DAC.
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
   * This class template is meant for use as the `FrameTransmitter` template
   * parameter of @ref FrameOutputHandler.
   * 
   * When using this frame transmitter, frames are transmitted over a channel
   * using the frame transfer API in `mic_array/frame_transfer.h`.
   * \verbatim embed:rst
     Usually, a call to :c:func:`ma_frame_rx()` (with the other end of 
     `c_frame_out` as argument) should be used to receive the frame on 
     another thread. \endverbatim
   * 
   * If the receiving thread is not waiting to receive the frame when @ref
   * OutputFrame() is called, that method will block until the frame has been
   * transmitted. In order to ensure there are no violations of the mic array's
   * real-time constraints, the receiver should be ready to receive a frame as
   * soon as it becomes available.
   * 
   * @note While @ref OutputFrame() is blocking, it will not prevent the PDM rx
   * interrupt from firing.
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
       * 
       * If the default constructor is used, @ref SetChannel() must be called to
       * configure the channel over which frames are transmitted prior to any
       * calls to @ref OutputFrame(). 
       */
      chanend_t c_frame_out;

    public:

      /**
       * @brief Construct a `ChannelFrameTransmitter`.
       * 
       * If this constructor is used, @ref SetChannel() must be called to
       * configure the channel over which frames are transmitted prior to any
       * calls to @ref OutputFrame(). 
       */
      ChannelFrameTransmitter() : c_frame_out(0) { }

      /**
       * @brief Construct a `ChannelFrameTransmitter`.
       * 
       * The supplied value of `c_frame_out` must be a valid chanend.
       * 
       * @param c_frame_out Chanend over which frames will be transmitted.
       */
      ChannelFrameTransmitter(chanend_t c_frame_out) : c_frame_out(c_frame_out) { }

      /**
       * @brief Set channel used for frame transfers.
       * 
       * The supplied value of `c_frame_out` must be a valid chanend.
       * 
       * @param c_frame_out Chanend over which frames will be transmitted.
       */
      void SetChannel(chanend_t c_frame_out);

      /**
       * @brief Get the chanend used for frame transfers.
       * 
       * @returns Channel to be used for frame transfers.
       */
      chanend_t GetChannel();

      /**
       * @brief Transmit the specified frame.
       * 
       * See @ref ChannelFrameTransmitter for additional details.
       * 
       * @param frame Frame to be transmitted.
       */
      void OutputFrame(int32_t frame[MIC_COUNT][SAMPLE_COUNT]);
  };

}  


//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////



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