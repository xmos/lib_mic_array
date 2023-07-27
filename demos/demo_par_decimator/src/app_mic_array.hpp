// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <type_traits>

#include "mic_array.h"
#include "app_decimator.hpp"
#include "mic_array/etc/filters_default.h"

// This has caused problems previously, so just catch the problems here.
#if defined(MIC_COUNT) || defined(MICS_IN) || defined(FRAME_SIZE) || defined(USE_DCOE)
# error Application must not define the following as precompiler macros: MIC_COUNT, MICS_IN, FRAME_SIZE, USE_DCOE.
#endif

/**
 * A copy of Prefab with TwoStageDecimator replaced with a custom MyTwoStageDecimator.
 * This implementation provides support for > 8 mics by using multiple cores to
 * perform the decimation process.
 */
namespace par_mic_array {
  template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN=MIC_COUNT>
  class ParMicArray
      : public mic_array::MicArray<MIC_COUNT,
                        MyTwoStageDecimator<MIC_COUNT, STAGE2_DEC_FACTOR,
                                  STAGE2_TAP_COUNT>,
                        mic_array::StandardPdmRxService<MICS_IN,MIC_COUNT,STAGE2_DEC_FACTOR>,
                        // std::conditional uses USE_DCOE to determine which
                        // sample filter is used.
                        typename std::conditional<USE_DCOE,
                                            mic_array::DcoeSampleFilter<MIC_COUNT>,
                                            mic_array::NopSampleFilter<MIC_COUNT>>::type,
                        mic_array::FrameOutputHandler<MIC_COUNT, FRAME_SIZE,
                                            mic_array::ChannelFrameTransmitter>>
  {

    public:
      /**
       * `TParent` is an alias for this class template from which this class
       * template inherits.
       */
      using TParent = mic_array::MicArray<MIC_COUNT,
                                MyTwoStageDecimator<MIC_COUNT, STAGE2_DEC_FACTOR,
                                          STAGE2_TAP_COUNT>,
                                mic_array::StandardPdmRxService<MICS_IN,MIC_COUNT,STAGE2_DEC_FACTOR>,
                                typename std::conditional<USE_DCOE,
                                          mic_array::DcoeSampleFilter<MIC_COUNT>,
                                          mic_array::NopSampleFilter<MIC_COUNT>>::type,
                                mic_array::FrameOutputHandler<MIC_COUNT, FRAME_SIZE,
                                  mic_array::ChannelFrameTransmitter>>;


      /**
       * @brief No-argument constructor.
       *
       *
       * This constructor allocates the mic array and nothing more.
       *
       * Call ParMicArray::Init() to initialize the decimator.
       *
       * Subsequent calls to `ParMicArray::SetPort()` and
       * `ParMicArray::SetOutputChannel()` will also be required before any
       * processing begins.
       */
      constexpr ParMicArray() noexcept {}

      /**
       * @brief Initialize the decimator.
       */
      void Init();

      /**
       * @brief Initializing constructor.
       *
       * If the communication resources required by `ParMicArray` are known
       * at construction time, this constructor can be used to avoid further
       * initialization steps.
       *
       * This constructor does _not_ install the ISR for PDM rx, and so that
       * must be done separately if PDM rx is to be run in interrupt mode.
       *
       * @param p_pdm_mics    Port with PDM microphones
       * @param c_frames_out  (non-streaming) chanend used to transmit frames.
       */
      ParMicArray(
          port_t p_pdm_mics,
          chanend_t c_frames_out);

      /**
       * @brief Set the PDM data port.
       *
       * This function calls `this->PdmRx.Init(p_pdm_mics)`.
       *
       * This should be called during initialization.
       *
       * @param p_pdm_mics  The port to receive PDM data on.
       */
      void SetPort(
          port_t p_pdm_mics);

      /**
       * @brief Set the audio frame output channel.
       *
       * This function calls
       * `this->OutputHandler.FrameTx.SetChannel(c_frames_out)`.
       *
       * This must be set prior to entering the decimator task.
       *
       * @param c_frames_out The channel to send audio frames on.
       */
      void SetOutputChannel(
          chanend_t c_frames_out);

      /**
       * @brief Entry point for PDM rx thread.
       *
       * This function calls `this->PdmRx.ThreadEntry()`.
       *
       * @note This call does not return.
       */
      void PdmRxThreadEntry();

      /**
       * @brief Install the PDM rx ISR on the calling thread.
       *
       * This function calls `this->PdmRx.InstallISR()`.
       */
      void InstallPdmRxISR();

      /**
       * @brief Unmask interrupts on the calling thread.
       *
       * This function calls `this->PdmRx.UnmaskISR()`.
       */
      void UnmaskPdmRxISR();


  };

}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void par_mic_array::ParMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>::Init()
{
  this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
par_mic_array::ParMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::ParMicArray(
        port_t p_pdm_mics,
        chanend_t c_frames_out) : TParent(
            mic_array::StandardPdmRxService<MICS_IN, MIC_COUNT, STAGE2_DEC_FACTOR>(p_pdm_mics),
            mic_array::FrameOutputHandler<MIC_COUNT, FRAME_SIZE,
                mic_array::ChannelFrameTransmitter>(
                    mic_array::ChannelFrameTransmitter<MIC_COUNT, FRAME_SIZE>(
                        c_frames_out)))
{
  this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void par_mic_array::ParMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::SetOutputChannel(chanend_t c_frames_out)
{
  this->OutputHandler.FrameTx.SetChannel(c_frames_out);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void par_mic_array::ParMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::SetPort(port_t p_pdm_mics)
{
  this->PdmRx.Init(p_pdm_mics);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void par_mic_array::ParMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::PdmRxThreadEntry()
{
  this->PdmRx.ThreadEntry();
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void par_mic_array::ParMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::InstallPdmRxISR()
{
  this->PdmRx.InstallISR();
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void par_mic_array::ParMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::UnmaskPdmRxISR()
{
  this->PdmRx.UnmaskISR();
}
