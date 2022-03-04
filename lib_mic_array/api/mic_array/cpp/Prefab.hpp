#pragma once

#include <type_traits>

#include "MicArray.hpp"
#include "mic_array/etc/filters_default.h"


namespace mic_array {

  /**
   * @brief Namespace containing simplified versions of `MicArray`.
   * 
   * This namespace contains simplified implementations of the `MicArray` class 
   * where its components (e.g. `MicArray.Decimator` or `MicArray.PdmRx`) are 
   * already baked in.
   * 
   * Most applications need not extend of modify the standard mic array 
   * behavior, and so using one of the templates defined here will usually be
   * the right choice.
   */
  namespace prefab {

    /**
     * @brief Class template for typical bare-metal mic array module.
     * 
     * This prefab is likely the right starting point for most bare-metal (i.e.
     * not using an RTOS) applications.
     * 
     * With this prefab, the decimator will consume one device core, and the
     * PDM rx service can be run either as an interrupt, or as an additional
     * thread. The benefit of running PDM rx as a thread is decreased MIPS 
     * usage, but the drawback is that it consumes a core.
     * 
     * For the first and second stage decimation filters, this prefab uses the 
     * coefficients provided with this library. The first stage uses a 
     * (non-configurable) decimation factor of 32, and the second stage is 
     * configured to use a decimation factor of 6.
     * 
     * To get 16 kHz audio output from the `BasicMicArray` prefab, then, the
     * PDM clock must be configured to `3.072 MHz`  
     * (`3.072 MHz / (32 * 6) = 16 kHz`).
     * 
     * 
     * @par Template Parameters Details
     * 
     * The template parameter `MIC_COUNT` is the number of microphone channels
     * to be read and processed. If the device's microphones are configured in
     * SDR mode (i.e. 1 microphone per port pin), then this will be the same
     * as the port width. If the microphones are running in DDR mode, this will
     * be twice the port width.
     * 
     * This prefab (and this version of this library) does not presently support
     * using, for example, only the first two pins of a 4-bit port to produce
     * two channels of output audio.
     * 
     * The template parameter `FRAME_SIZE` is the number of samples in each 
     * output frame produced by the mic array. Frame data is communicated using
     * the API found in `mic_array/frame_transfer.h`. Typically 
     * `ma_frame_rx_s32()` will be the right function to use in a receiving 
     * thread t retrieve audio frames. 
     * 
     * `ma_frame_rx_s32()` will block until a frame becomes available on the
     * specified chanend.
     * 
     * @warning If the receiving thread is not waiting to retrieve the audio
     *          frame from the decimator thread when it becomes available, the
     *          pipeline may back up and cause samples to be dropped. It is the
     *          responsibility of the application developer to ensure this does
     *          not happen.
     * 
     * The template boolean parameter `USE_DCOE` indicates whether the DC offset 
     * elimination filter should be applied to the output of the second stage
     * decimator. DC offset elimination is an IIR filter intended to ensure 
     * audio samples on each channel tend towards zero-mean.
     * 
     * See @todo for more information about DC offset elimination.
     * 
     * If `USE_DCOE` is `false`, no further filtering of the second stage
     * decimator's output will occur.
     * 
     * @par Allocation and Initialization
     * 
     * The initialization in this section must occur prior to starting the
     * decimator or PDM rx threads (or PDM rx ISR if running in ISR mode).
     * 
     * Static allocation of an instance of the `BasicMicArray` prefab can be
     * achieved as follows:
     * 
     * @code{.cpp}
     *    #include "mic_array/cpp/Prefab.hpp"
     *    ...
     *    using AppMicArray = mic_array::prefab::BasicMicArray<MICS,SAMPS,DCOE>;
     *    AppMicArray mics;
     * @endcode
     * 
     * @todo Add documentation for correctly configuring ports and clocks.
     * 
     * `BasicMicArray` uses the `StandardPdmRxService` which needs to know the
     * port on which it will capture PDM data and it needs a streaming channel
     * over which PDM data will be communicated to the decimator thread. To
     * set these, `StandardPdmRxService::Init()` may be used, which takes each
     * as an argument. That method is available on `BasicMicArray`'s `PdmRx`
     * member field.
     * 
     * @code{.cpp}
     *    extern "C"
     *    void app_init_pdm_rx(port_t p_pdm_mic_data, 
     *                         streaming_channel_t c_pdm_data) {
     *      mics.PdmRx.Init(p_pdm_mic_data, c_pdm_data);
     *    }
     * @endcode
     * 
     * `BasicMicArray` uses a `ChannelFrameTransmitter` to transmit frames to
     * the next stage of the pipeline. A `ChannelFrameTransmitter` needs to know
     * the chanend on which to send data. 
     * `ChannelFrameTransmitter::SetChannel()` can be used to set this. This 
     * method can be accessed in this example through 
     * `mics.OutputHandler.FrameTx`.
     * 
     * @code{.cpp}
     *    extern "C"
     *    void app_init_frame_tx(chanend_t c_frame_out) {
     *      mics.OutputHandler.FrameTx.SetChannel(c_frame_out);
     *    }
     * @endcode
     * 
     * Finally, iff the PDM rx service is running in ISR mode, the ISR must be
     * installed on the core on which it will execute. We recommend this be the
     * same core on which the decimator thread operates. Installing the ISR on
     * a core is accomplished with a call to `mics.PdmRx.InstallISR()` from the
     * core it will be installed on.
     * 
     * @code{.cpp}
     *    extern "C"
     *    void app_install_pdm_rx_isr() {
     *      mics.PdmRx.InstallISR();
     *    }
     * @endcode
     * 
     * @par Begin mic array processing
     * 
     * To start the PDM rx service, you must first choose whether it will 
     * operate as a stand-alone thread or as an interrupt. Running it as an
     * interrupt avoids using a hardware core, but has additional processing
     * overhead.
     * 
     * @note Running the PDM rx service as a thread will _not_ consume all the 
     *       MIPS available to that core, but under typical circumstances, this
     *       does _not_ mean those MIPS are wasted. xCore devices currently use
     *       a 5-stage pipeline and have 8 hardware cores. When there is no work
     *       for the PDM rx thread to do (between port reads), the core will not
     *       issue instructions to the core pipeline, which means other hardware
     *       threads will have more frequent opportunities to issue 
     *       instructions.
     * 
     * To run PDM rx as an interrupt, `InstallISR()` must have been called to
     * initialize the interrupt (as mentioned above), and to begin processing,
     * `UnmaskISR()` must be called on the `PdmRx` member of `BasicMicArray`.
     * 
     * To run PDM rx as a thread, spawn a thread in the usual way, where the
     * `ThreadEntry` member function of `StandardPdmRxService` is the thread
     * entry point. E.g.  `mics.PdmRx.ThreadEntry`.
     * 
     * Once the PDM rx thread is launched or the PDM rx interrupt has been 
     * unmasked, PDM data will start being collected and reported to the 
     * decimator thread. The application then must start the decimator thread
     * within one output sample time (i.e. sample time for the output of the
     * second stage decimator) to avoid issues.
     * 
     * The thread entry point for the decimator thread is 
     * `BasicMicArray::ThreadEntry`.
     * 
     * Once the decimator thread is running, the real-time constraint is active
     * for the thread consuming the decimator output, and it must waiting to
     * receive an audio frame within one frame time.
     * 
     * @par Initializing and launching mic array from C or XC
     * 
     * This version of the library implements the core `MicArray`-related 
     * structures in C++ using template classes for simplicity, flexibility and
     * efficiency. Unfortunately, because template classes are used, the library
     * cannot reasonably supply C wrapper functions for each class's methods so
     * that they can be called from C or XC. This means an application will have
     * to provide them itself, if needed.
     * 
     * The recommended way to accomplish this can be seen in the 
     * `mic_array_vanilla.cpp` source file provided with this library (See @todo
     * for information about the 'vanilla' API). It is accomplished by including
     * a CPP file in the application source (where the `MicArray` object can 
     * also be statically allocated) and writing C-compatible (`extern "C"`) 
     * wrappers for intialization and thread launch, as demonstrated above.
     * 
     * If threads are launched from a `par` block in an XC `main()`, instead of
     * directly calling e.g. `mics.ThreadEntry()` in the par block, call the 
     * C-compatible wrapper function. If PDM rx is run in interrupt mode, the
     * decimator thread's wrapper function can also unmask interrupts.
     * 
     * Check out the "vanilla" demo app included with this library to see this
     * in action.
     * 
     * @par Hardware resource usage
     * 
     * @todo
     * 
     * @par Configuring ports and clock blocks
     * 
     * @todo: Point to documentation for configuring the ports and clock blocks.
     * 
     * 
     * @tparam MIC_COUNT  Number of microphone channels.
     * @tparam FRAME_SIZE Number of samples in each output audio frame.
     * @tparam USE_DCOE   Whether DC offset elimination should be used.
     */
    template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE>
    class BasicMicArray 
        : public MicArray<MIC_COUNT,
                          Decimator<MIC_COUNT, STAGE2_DEC_FACTOR, 
                                    STAGE2_TAP_COUNT>,
                          StandardPdmRxService<MIC_COUNT * STAGE2_DEC_FACTOR>, 
                          // std::conditional uses USE_DCOE to determine which 
                          // sample filter is used.
                          typename std::conditional<USE_DCOE,
                                              DcoeSampleFilter<MIC_COUNT>,
                                              NopSampleFilter<MIC_COUNT>>::type,
                          FrameOutputHandler<MIC_COUNT, FRAME_SIZE, 
                                             ChannelFrameTransmitter>>
    {

      public:

        using TParent = MicArray<MIC_COUNT,
                                 Decimator<MIC_COUNT, STAGE2_DEC_FACTOR, 
                                           STAGE2_TAP_COUNT>,
                                 StandardPdmRxService<MIC_COUNT 
                                                      * STAGE2_DEC_FACTOR>, 
                                 typename std::conditional<USE_DCOE,
                                            DcoeSampleFilter<MIC_COUNT>,
                                            NopSampleFilter<MIC_COUNT>>::type,
                                 FrameOutputHandler<MIC_COUNT, FRAME_SIZE, 
                                    ChannelFrameTransmitter>>;


        /**
         * @brief No-argument constructor.
         * 
         * This constructor will intialize the decimator, but will not set the
         * port and channel resources needed to actually run the mic array.
         * 
         * Subsequent calls to `BasicMicArray::PdmRx::Init()` and 
         * `BasicMicArray::OutputHandler::FrameTx::SetChannel()` will be 
         * required before any processing begins.
         */
        BasicMicArray()
        {
          this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, stage2_shr);
        }

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
         * @param c_pdm_data    Streaming channel for PDM blocks
         * @param c_frames_out  (non-streaming) chanend used to transmit frames.
         */
        BasicMicArray(
                port_t p_pdm_mics,
                streaming_channel_t c_pdm_data,
                chanend_t c_frames_out) : TParent(
                    StandardPdmRxService<MIC_COUNT * STAGE2_DEC_FACTOR>(
                                                                  p_pdm_mics, 
                                                                  c_pdm_data), 
                    FrameOutputHandler<MIC_COUNT, FRAME_SIZE, 
                                       ChannelFrameTransmitter>(
                        ChannelFrameTransmitter<MIC_COUNT, FRAME_SIZE>(
                                                              c_frames_out)))
        { 
          this->Decimator.Init((uint32_t*) stage1_coef, stage2_coef, 
                                stage2_shr);
        }

    };

  }
}