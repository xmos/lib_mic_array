// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"


C_API_START

/**
 * @brief Initializes the mic array task
 *
 * Initializes the contexts for the decimator thread and configures
 * the clocks and ports for PDM reception. Note that this does not start any threads
 * or PDM capture.
 *
 * After calling this, the PDM clock is active and signaling, but the PDM rx
 * service has not been activated (when running in the interrupt context)/PDM rx thread
 * is not created (when running in thread context) so the received PDM samples are
 * ignored.
 *
 * @param pdm_res     Pointer to the pdm_rx_resources_t struct containing hardware resources
 *                    required by the mic array module.
 * @param channel_map Array containing MIC_ARRAY_CONFIG_MIC_IN_COUNT to MIC_ARRAY_CONFIG_MIC_COUNT mapping.
 *                    array dimension should be MIC_ARRAY_CONFIG_MIC_COUNT, and the i<sup>th</sup> entry is the
 *                    input pdm pin index mapped to mic array output index i
 * @param output_samp_freq output PCM sampling frequency (supported values are 16, 32 and 48KHz)
 */
MA_C_API
void mic_array_init(pdm_rx_resources_t *pdm_res, const unsigned *channel_map, unsigned output_samp_freq);

/**
 * @brief Initialize the mic array using application-supplied decimation filter and PDM RX buffers.
 *
 * All memory referenced by @p mic_array_conf must be allocated and owned by the
 * caller and must remain valid for the lifetime of the mic array task, i.e., until
 * @ref mic_array_start returns. This excludes the @ref mic_array_conf_t structure
 * itself and the @ref mic_array_decimator_conf_t::filter_conf array, which may reside on the caller’s stack.
 *
 * After successful initialization, the PDM clock is configured and started, but
 * no threads/ISRs are running until mic_array_start() is called.
 *
 * @param pdm_res         Pointer to hardware resources used by the mic array module
 *                        (ports, clocks, and chanends).
 * @param mic_array_conf  Pointer to top-level configuration that bundles the decimator
 *                        pipeline configuration (@ref mic_array_decimator_conf_t) and
 *                        the PDM RX configuration (@ref pdm_rx_conf_t).
 *
 * @note The caller owns the buffers referenced by @p mic_array_conf and must ensure
 *       correct sizing and required alignment of these buffers.
 */
MA_C_API
void mic_array_init_custom_filter(pdm_rx_resources_t* pdm_res, mic_array_conf_t* mic_array_conf);

/**
 * @brief Start the mic array task
 *
 * This function sets up and activates the PDM rx service in ISR mode (when MIC_ARRAY_CONFIG_USE_PDM_ISR=1), and then
 * immediately begins executing the decimator.
 * When MIC_ARRAY_CONFIG_USE_PDM_ISR=0, it starts the PDM rx service and decimator as 2 parallel threads
 *
 * After calling this the real-time condition is active, meaning there must be
 * another thread waiting to pull frames from the other end of `c_frames_out`
 * as they become available.
 *
 * @param c_frames_out  (Non-streaming) Channel over which to send processed
 *                      frames of audio.
 */
MA_C_API
void mic_array_start(chanend_t c_frames_out);


C_API_END
