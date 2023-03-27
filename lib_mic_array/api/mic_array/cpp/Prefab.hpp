// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <type_traits>

#include "MicArray.hpp"
#include "mic_array/etc/filters_default.h"

// This has caused problems previously, so just catch the problems here.
#if defined(MIC_COUNT) || defined(MICS_IN) || defined(FRAME_SIZE) || defined(USE_DCOE)
# error Application must not define the following as precompiler macros: MIC_COUNT, MICS_IN, FRAME_SIZE, USE_DCOE.
#endif

namespace mic_array {

  /**
   * @brief Namespace containing simplified versions of `MicArray`.
   * 
   * This namespace contains simplified implementations of the `MicArray` class 
   * where its component types (e.g. `MicArray.Decimator` or `MicArray.PdmRx`) 
   * are already baked in, simplifying usage in an application.
   * 
   * Most applications need not extend or modify the typical mic array behavior,
   * and so using one of the templates defined here will usually be the right
   * choice.
   */
  namespace prefab {

    /**
     * @brief Class template for a typical bare-metal mic array unit.
     * 
     * This prefab is likely the right starting point for most applications.
     * 
     * With this prefab, the decimator will consume one device core, and the
     * PDM rx service can be run either as an interrupt, or as an additional
     * thread. Normally running as an interrupt is recommended.
     * 
     * For the first and second stage decimation filters, this prefab uses the
     * coefficients provided with this library. The first stage uses a
     * decimation factor of 32, and the second stage is configured to use a
     * decimation factor of 6.
     * 
     * To get 16 kHz audio output from the `BasicMicArray` prefab, then, the
     * PDM clock must be configured to `3.072 MHz`  
     * (`3.072 MHz / (32 * 6) = 16 kHz`).
     * 
     * @par Sub-Components
     * @parblock
     * Being derived from @ref mic_array::MicArray, an instance of
     * `BasicMicArray` has 4 sub-components responsible for different portions
     * of the work being done. These sub-components are `PdmRx`, `Decimator`,
     * `SampleFilter` and `OutputHandler`. See the documentation for `MicArray`
     * for more details about these.
     * @endparblock
     * 
     * @par Template Parameters Details 
     * @parblock
     * The template parameter `MIC_COUNT` is the number of microphone channels
     * to be processed and output. 
     * 
     * The template parameter `FRAME_SIZE` is the number of samples in each
     * output frame produced by the mic array. Frame data is communicated using
     * the API found in `mic_array/frame_transfer.h`. 
     * \verbatim embed:rst
       Typically :c:func:`ma_frame_rx()` will be the right function to use in a 
       receiving thread to retrieve audio frames. ``ma_frame_rx()`` receives 
       audio frames with shape ``(MIC_COUNT,FRAME_SIZE)``, meaning that all 
       samples corresponding to a given channel will end up in a contiguous 
       block of memory. Instead of ``ma_frame_rx()``, 
       :c:func:`ma_frame_rx_transpose()` can be used to swap the dimensions, 
       resulting in the shape ``(FRAME_SIZE, MIC_COUNT)``.\endverbatim
     * 
     * Note that calls to `ma_frame_rx()` or `ma_frame_rx_transpose()` will
     * block until a frame becomes available on the specified chanend.
     * 
     * If the receiving thread is not waiting to retrieve the audio frame from
     * the mic array when it becomes available, the pipeline may back up and
     * cause samples to be dropped. It is the responsibility of the application
     * developer to ensure this does not happen.
     * 
     * The boolean template parameter `USE_DCOE` indicates whether the DC offset
     * elimination filter should be applied to the output of the second stage
     * decimator. DC offset elimination is an IIR filter intended to ensure
     * audio samples on each channel tend towards zero-mean.
     * 
     * \verbatim embed:rst 
       For more information about DC offset elimination, see 
       :ref:`sample_filters` \endverbatim.
     *
     * If `USE_DCOE` is `false`, no further filtering of the second stage
     * decimator's output will occur.
     * 
     * The template parameter `MICS_IN` indicates the number of microphone
     * channels to be captured by the `PdmRx` component of the mic array unit.
     * This will often be the same as `MIC_COUNT`, but in some applications,
     * `MIC_COUNT` microphones must be physically connected to an XCore port
     * which is not `MIC_COUNT` (SDR) or `MIC_COUNT/2` (DDR) bits wide.
     *
     * In these cases, capturing the additional channels (likely not even
     * physically connected to PDM microphones) is unavoidable, but further
     * processing of the additional (junk) channels can be avoided by using
     * `MIC_COUNT < MICS_IN`. The mapping which tells the mic array unit how to
     * derive output channels from input channels can be configured during
     * initialization by calling `StandardPdmRxService::MapChannels()` on the
     * `PdmRx` sub-component of the `BasicMicarray`.
     *
     * If the application uses an SDR microphone configuration (i.e. 1
     * microphone per port pin), then `MICS_IN` must be the same as the port
     * width. If the application is running in a DDR microphone configuration,
     * `MICS_IN` must be twice the port width. `MICS_IN` defaults to
     * `MIC_COUNT`.
     * @endparblock
     * 
     * @par Allocation
     * @parblock
     * Before a mic array unit can be started or initialized, it must be
     * allocated.
     * 
     * Instances of `BasicMicArray` are self-contained with respect to memory,
     * needing no external buffers to be supplied by the application. Allocating
     * an instance is most easily accomplished by simply declaring the mic array
     * unit. An example follows.
     * 
     * @code{.cpp}
     * #include "mic_array/cpp/Prefab.hpp"
     * ...
     * using AppMicArray = mic_array::prefab::BasicMicArray<MICS,SAMPS,DCOE>;
     * AppMicArray mics;
     * @endcode
     * 
     * Here, `mics` is an allocated mic array unit. The example (and all that
     * follow) assumes the macros used for template parameters are defined
     * elsewhere.
     * @endparblock
     * 
     * @par Initialization
     * @parblock
     * Before a mic array unit can be started, it must be initialized.
     * 
     * `BasicMicArray` reads PDM samples from an XCore port, and delivers frames
     * of audio data over an XCore channel. To this end, an instance of
     * `BasicMicArray` needs to be given the resource IDs of the port to be read
     * and the chanend to transmit frames over. This can be accomplished in
     * either of two ways.
     * 
     * If the resource IDs for the port and chanend are available as the mic
     * array unit is being allocated, one option is to explicitly construct the
     * `BasicMicArray` instance with the required resource IDs using the
     * two-argument constructor:
     * 
     * @code{.cpp}
     * using AppMicArray = mic_array:prefab::BasicMicArray<MICS,SAMPS,DCOE>;
     * AppMicArray mics(PORT_PDM_MICS, c_frames_out);
     * @endcode
     * 
     * Otherwise (typically), these can be set using
     * `BasicMicArray::SetPort(port_t)` and
     * `BasicMicArray::SetOutputChannel(chanend_t)` to set the port and channel
     * respectively.
     * 
     * @code{.cpp}
     * AppMicArray mics;
     * ...
     * void app_init(port_t p_pdm_mics, chanend_t c_frames_out)
     * {
     *  mics.SetPort(p_pdm_mics);
     *  mics.SetOutputChannel(p_pdm_mics);
     * }
     * @endcode
     * 
     * Next, the ports and clock block(s) used by the PDM rx service need to be
     * configured appropriately. This is not accomplished directly through the
     * `BasicMicArray` object. Instead, a `pdm_rx_resources_t` struct
     * representing these hardware resources is constructed and passed to
     * `mic_array_resources_configure()`. See the documentation for
     * `pdm_rx_resources_t` and `mic_array_resources_configure()` for more
     * details.
     * 
     * Finally, if running `BasicMicArray`'s PDM rx service within an ISR,
     * before the mic array unit can be started, the ISR must be installed. This
     * is accomplished with a call to `BasicMicArray::InstallPdmRxISR()`.
     * Installing the ISR will _not_ unmask it.
     * 
     * @note `BasicMicArray::InstallPdmRxISR()` installs the ISR on the
     * hardware thread that calls the method. In most cases, installing it in
     * the same thread as the decimator is the right choice.
     * @endparblock
     * 
     * @par Begin Processing (PDM rx ISR)
     * @parblock
     * After it has been initialized, starting the mic array unit with the PDM
     * rx service running as an ISR, three steps are required.
     *
     * First, the PDM clock must be started. This is accomplished with a call to
     * `mic_array_pdm_clock_start()`. The same `pdm_rx_resources_t` that was
     * passed to `mic_array_resources_configure()` is given as an argument here.
     * 
     * Second, the PDM rx ISR that was installed during initialization must be
     * unmasked. This is accomplished by calling
     * `BasicMicArray::UnmaskPdmRxISR()` on the mic array unit.
     *
     * Finally, the mic array processing thread must be started. The entry point
     * for the mic array thread is `BasicMicArray::ThreadEntry()`.
     * 
     * A typical pattern will include all three of these steps in a single
     * function which wraps the mic array thread entry point.
     * 
     * @code{.cpp}
     * AppMicArray mics;
     * pdm_rx_resources_t pdm_res;
     * ...
     * MA_C_API  // alias for 'extern "C"'
     * void app_mic_array_task()
     * {
     *  mic_array_pdm_clock_start(&pdm_res);
     *  mics.UnmaskPdmRxISR();
     *  mics.ThreadEntry();
     * }
     * @endcode
     * 
     * Using this pattern, `app_mic_array_task()` is a C-compatible function
     * which can be called from a multi-tile `main()` in an XC file. Then,
     * `app_mic_array_task()` is called directly from a `par {...}` block. For
     * example,
     * 
     * @code{.c}
     * main(){
     *  ...
     *  par {
     *    on tile[1]: {
     *      ... // Do initialization stuff
     *      
     *      par {
     *        app_mic_array_task();
     *        ...
     *        other_thread_on_tile1(); // other threads
     *      }
     *    }
     *  }
     * }
     * @endcode
     * @endparblock
     * 
     * @par Begin Processing (PDM Rx Thread)
     * @parblock
     * The procedure for running the mic array unit with the PDM rx component
     * running as a stand-alone thread is much the same with just a couple key
     * differences.
     * 
     * When running PDM rx as a thread, no call to
     * `BasicMicArray::UnmaskPdmRxISR()` is necessary. Instead, the
     * application spawns a second thread (the first being the mic array
     * processing thread) using `BasicMicArray::PdmRxThreadEntry()` as the
     * entry point.
     * 
     * `mic_array_pdm_clock_start()` must still be called, but here the
     * requirement is that it be called from the hardware thread on which the
     * PDM rx component is running (which, of course, cannot be the mic array
     * thread).
     * 
     * A typical application with a multi-tile XC `main()` will provide two
     * C-compatible functions - one for each thread:
     * 
     * @code{.cpp}
     * MA_C_API
     * void app_pdm_rx_task()
     * {
     *  mic_array_pdm_clock_start(&pdm_res);
     *  mics.PdmRxThreadEntry();
     * }
     * 
     * MA_C_API
     * void app_mic_array_task()
     * {
     *  mics.ThreadEntry();
     * }
     * @endcode
     * 
     * Notice that `app_mic_array_task()` above is a thin wrapper for
     * `mics.ThreadEntry()`. Unfortunately, because the type of `mics` is a C++
     * class, `mics.ThreadEntry()` cannot be called directly from an XC file
     * (including the one containing `main()`). Further, because a C++ class
     * template was used, this library cannot provide a generic C-compatible
     * call wrapper for the methods on a `MicArray` object. This unfortunately
     * means it is necessary in some cases to create a thin wrapper such as
     * `app_mic_array_task()`.
     * 
     * The threads are spawned from XC main using a `par {...}` block:
     * 
     * @code{.c}
     * main(){
     *  ...
     *  par {
     *    on tile[1]: {
     *      ... // Do initialization stuff
     *      
     *      par {
     *        app_mic_array_task();
     *        app_pdm_rx_task();
     *        ...
     *        other_thread_on_tile1(); // other threads
     *      }
     *    }
     *  }
     * }
     * @endcode
     * @endparblock
     * 
     * @par Real-Time Constraint
     * @parblock
     * Once the PDM rx thread is launched or the PDM rx interrupt has been
     * unmasked, PDM data will start being collected and reported to the
     * decimator thread. The application then must start the decimator thread
     * within one output sample time (i.e. sample time for the output of the
     * second stage decimator) to avoid issues.
     *
     * Once the mic array processing thread is running, the real-time constraint
     * is active for the thread consuming the mic array unit's output, and it
     * must waiting to receive an audio frame within one frame time.
     * @endparblock
     * 
     * @par Examples
     * @parblock
     * This library comes with examples which demonstrate how a mic array unit
     * is used in an actual application. If you are encountering difficulties
     * getting `BasicMicArray` to work, studying the provided examples may help.
     * @endparblock
     * 
     * @tparam MIC_COUNT  Number of microphone channels.
     * @tparam FRAME_SIZE Number of samples in each output audio frame.
     * @tparam USE_DCOE   Whether DC offset elimination should be used.
     */
    template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN=MIC_COUNT>
    class BasicMicArray 
        : public MicArray<MIC_COUNT,
                          TwoStageDecimator<MIC_COUNT, STAGE2_DEC_FACTOR, 
                                    STAGE2_TAP_COUNT>,
                          StandardPdmRxService<MICS_IN,MIC_COUNT,STAGE2_DEC_FACTOR>, 
                          // std::conditional uses USE_DCOE to determine which 
                          // sample filter is used.
                          typename std::conditional<USE_DCOE,
                                              DcoeSampleFilter<MIC_COUNT>,
                                              NopSampleFilter<MIC_COUNT>>::type,
                          FrameOutputHandler<MIC_COUNT, FRAME_SIZE, 
                                             ChannelFrameTransmitter>>
    {

      public:
        /**
         * `TParent` is an alias for this class template from which this class
         * template inherits.
         */
        using TParent = MicArray<MIC_COUNT,
                                 TwoStageDecimator<MIC_COUNT, STAGE2_DEC_FACTOR, 
                                           STAGE2_TAP_COUNT>,
                                 StandardPdmRxService<MICS_IN,MIC_COUNT,STAGE2_DEC_FACTOR>, 
                                 typename std::conditional<USE_DCOE,
                                            DcoeSampleFilter<MIC_COUNT>,
                                            NopSampleFilter<MIC_COUNT>>::type,
                                 FrameOutputHandler<MIC_COUNT, FRAME_SIZE, 
                                    ChannelFrameTransmitter>>;


        /**
         * @brief No-argument constructor.
         * 
         * 
         * This constructor allocates the mic array and nothing more.
         * 
         * Call BasicMicArray::Init() to initialize the decimator.
         * 
         * Subsequent calls to `BasicMicArray::SetPort()` and
         * `BasicMicArray::SetOutputChannel()` will also be required before any
         * processing begins.
         */
        constexpr BasicMicArray() noexcept {}

        /**
         * @brief Initialize the decimator.
         */
        void Init();

        /**
         * @brief Initialzing constructor.
         * 
         * If the communication resources required by `BasicMicArray` are known
         * at construction time, this constructor can be used to avoid further
         * initialization steps.
         * 
         * This constructor does _not_ install the ISR for PDM rx, and so that
         * must be done separately if PDM rx is to be run in interrupt mode.
         * 
         * @param p_pdm_mics    Port with PDM microphones
         * @param c_frames_out  (non-streaming) chanend used to transmit frames.
         */
        BasicMicArray(
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
         * This must be set prior to entrying the decimator task.
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
}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void mic_array::prefab::BasicMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>::Init()
{
  this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
mic_array::prefab::BasicMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::BasicMicArray(
        port_t p_pdm_mics,
        chanend_t c_frames_out) : TParent(
            StandardPdmRxService<MICS_IN, MIC_COUNT, STAGE2_DEC_FACTOR>(p_pdm_mics), 
            FrameOutputHandler<MIC_COUNT, FRAME_SIZE, 
                ChannelFrameTransmitter>(
                    ChannelFrameTransmitter<MIC_COUNT, FRAME_SIZE>(
                        c_frames_out)))
{
  this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void mic_array::prefab::BasicMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::SetOutputChannel(chanend_t c_frames_out)
{
  this->OutputHandler.FrameTx.SetChannel(c_frames_out);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void mic_array::prefab::BasicMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::SetPort(port_t p_pdm_mics)
{
  this->PdmRx.Init(p_pdm_mics);
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void mic_array::prefab::BasicMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::PdmRxThreadEntry()
{
  this->PdmRx.ThreadEntry();
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void mic_array::prefab::BasicMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::InstallPdmRxISR()
{
  this->PdmRx.InstallISR();
}


template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE, unsigned MICS_IN>
void mic_array::prefab::BasicMicArray<MIC_COUNT, FRAME_SIZE, USE_DCOE, MICS_IN>
    ::UnmaskPdmRxISR()
{
  this->PdmRx.UnmaskISR();
}
