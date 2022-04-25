// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

/**
 * @defgroup mic_array_vanilla_h_ mic_array_vanilla.h
 */


C_API_START

/**
 * @brief Indicates whether the mic array basic mode API is enabled.
 * 
 * For many applications, a simple out-of-the-box configuration is all that is
 * needed from the mic array module. The basic mode API is a way of configuring
 * lib_mic_array behavior for such applications.
 * 
 * Basic mode simplifies configuration by allocating the necessary contexts and
 * buffers within the library for the user _at compile time_, and by providing
 * a couple simple calls to initialize and begin processing. In standard mode
 * (i.e. not basic mode), it is the application source's responsibility to 
 * allocate and initialize these objects.
 * 
 * Basic mode uses a single core to both read in PDM data from a port (the PDM 
 * rx service in ISR mode) and process that data (the decimator thread) into
 * frames of filtered audio samples. Each time another frame of audio data 
 * becomes available, the decimator thread attempts to transfer the frame to
 * another thread using an xCore channel.
 * 
 * The receiving thread (typically) receives frames using `ma_frame_rx_s32()`
 * (see @ref `mic_array/frame_transfer.h`) and performs further 
 * application-specific processing of the data. In basic mode, the application
 * developer writes the receiving thread. The receiving thread (in basic or
 * standard mode) must be ready to receive new frames of audio as they become
 * available in order to avoid backing up the pipeline and ultimately dropping 
 * samples.
 * 
 * @par Basic Mode Setup
 * 
 * The first step to configure lib_mic_array in basic mode is to add the 
 * appropriate build flags to the lib_mic_array build target. These are 
 * preprocessor macros that enable basic mode and specify its parameters. The 
 * required macro definitions are:
 * 
 * * `MIC_ARRAY_BASIC_API_ENABLE=1` - Defining this to `1` enables basic mode.
 *    If this is not defined to a non-zero value, no symbols corresponding to
 *    basic mode will be available for linking.
 * * `MIC_ARRAY_CONFIG_MCLK_FREQ` - The master audio clock frequency, as an 
 *    integer expressed in Hz. The master audio clock is divided to generate the
 *    PDM clock. e.g. `-DMIC_ARRAY_CONFIG_MCLK_FREQ=24576000`
 * * `MIC_ARRAY_CONFIG_PDM_FREQ - The PDM clock frequency. This is used with
 *    `MIC_ARRAY_CONFIG_MCLK_FREQ` to determine the appropriate divider to 
 *    generate the PDM clock. e.g. `-DMIC_ARRAY_CONFIG_PDM_FREQ=3072000`
 * * `MIC_ARRAY_CONFIG_MIC_COUNT` - The number of microphones to be processed.
 *    This will be the number of audio channels in audio frames output by the
 *    mic array module. e.g. `-DMIC_ARRAY_CONFIG_MIC_COUNT=2`
 * 
 * The following preprocessor macros have default values that may be overridden
 * by the application:
 * 
 * * `MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME` - The number of samples in each frame
 *    that is output from the mic array module. This value defaults to `1`, so
 *    that each sample is transmitted separately. Most applications will want
 *    to process the audio stream in larger blocks. e.g. 
 *    `-DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=16`
 * * `MIC_ARRAY_CONFIG_USE_DC_ELIMINATION` - Indicates whether the DC offset
 *    elimination filter should be applied to the output of the second stage
 *    decimator. Default value is `1` (enabled). To disable, set this to `0`.
 *    e.g. `-DMIC_ARRAY_CONFIG_USE_DC_ELIMINATION=0`
 * 
 * With the appropriate preprocessor macros defined, the next step in your
 * application is to collect the hardware resources (ports and clock blocks)
 * required by the mic array into a `pdm_rx_resources_t` struct. In an XC file
 * this may look like:
 * 
 * @code
 *  // in main.xc; the ports to be used
 *  on tile[1]: in port p_mclk                     = XS1_PORT_1D;
 *  on tile[1]: out port p_pdm_clk                 = XS1_PORT_1G;
 *  on tile[1]: in buffered port:32 p_pdm_mics     = XS1_PORT_1F;
 *  ... 
 *  int main(){
 *    ... 
 *    par {
 *      on tile[1]: {
 *        pdm_rx_resources pdm_res = 
 *            pdm_rx_resources_sdr((port_t) p_mclk,
 *                                 (port_t) p_pdm_clk,
 *                                 (port_t) p_pdm_mics,
 *                                 (clock_t) MIC_ARRAY_CLK1);
 *        ...
 *      }
 *    }
 *  }
 * @endcode
 * 
 * Next, the mic array module needs to be initialized with a call to 
 * `ma_basic_init()`:
 * 
 * @code
 *  par {
 *    on tile[1]: {
 *      pdm_rx_resources pdm_res = ...;
 *      ...
 *      ma_basic_init(&pdm_res);
 *      ...
 *    }
 *  }
 * @endcode
 * 
 * Finally, the mic array thread (and the thread to receive audio) is launched
 * using `ma_basic_task()`:
 * 
 * @code
 *  par {
 *    on tile[1]: {
 *      pdm_rx_resources pdm_res = ... ;
 *      chan c_audio_frames;
 *      ...
 *      ma_basic_init(&pdm_res);
 *      ...
 *      par {
 *        ma_basic_task(&pdm_res, (chanend_t) c_audio_frames);
 *        ...
 *        audio_receive_thread((chanend_t) c_audio_frames, ...);
 *        ...
 *      }
 *    }
 *  }
 * @endcode
 * 
 * At this point the real-time condition is active and `audio_receive_thread()`
 * must be ready to receive frames from `ma_basic_task()` as they become
 * available.
 */
// #ifndef MIC_ARRAY_BASIC_API_ENABLE
// # define MIC_ARRAY_BASIC_API_ENABLE    (0)
// #endif

/**
 * @brief Initializes the mic array module (basic mode only).
 * 
 * Initializes the contexts for the decimator thread and configures
 * the clocks and ports for PDM reception.
 * 
 * After calling this, the PDM clock is active and signaling, but the PDM rx
 * service (ISR) has not yet been activated, so received PDM samples are
 * ignored. The real-time condition is not yet active.
 * 
 * @param pdm_res   Hardware resources required by the mic array module.
 * 
 * @ingroup mic_array_vanilla_h_
 */
MA_C_API
void ma_vanilla_init();


/**
 * @brief Entry point for decimator thread and PDM rx service (basic mode only).
 * 
 * This function sets up and activates the PDM rx service in ISR mode, and then
 * immediately begins executing the decimator.
 * 
 * After calling this the real-time condition is active, meaning there must be
 * another thread waiting to pull frames from the other end of `c_frames_out`
 * as they become available.
 * 
 * @param pdm_res   Hardware resources required by the mic array module.
 * @param c_frames_out  (Non-streaming) Channel over which to send processed
 *                      frames of audio.
 * 
 * @ingroup mic_array_vanilla_h_
 */
MA_C_API
void ma_vanilla_task(chanend_t c_frames_out);

    
C_API_END