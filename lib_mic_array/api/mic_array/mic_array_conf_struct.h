// Copyright 2025-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DECIMATION_FILTER_CONF_H
#define DECIMATION_FILTER_CONF_H

#include <stdint.h>
#include "xmath/xmath.h"

C_API_START

/**
 * @brief Configuration for a single decimator stage (e.g., stage 1 or stage 2).
 * @details
 * All memory referenced by this structure is owned by the caller. The caller
 * must allocate and initialize all buffers (coefficients and state) and ensure
 * that all pointers remain valid for the entire lifetime of the decimator.
 */
typedef struct
{
    /**
     * @brief Pointer to the filter coefficient array
     * @details
     * This buffer must be aligned to a 32-bit word boundary.
    */
    int32_t *coef;

    /**
     * @brief Pointer to filter state (delay line) buffer for all
     * microphones in int32_t words.
     * @details
     * For multi‑mic use this typically points to a buffer of
     * size `output_mic_count * @ref mic_array_filter_conf_t::num_taps` 32-bit words.
     *
     * This buffer must be aligned to a 32-bit word boundary.
     */
    int32_t *state;

    /**
     * @brief Final right-shift applied to the filter's accumulator prior to output.
     * @details
     * See lib_xcore_math xmath/filter.h (filter_fir_s32_t::shift) for details.
     */
    right_shift_t  shr;

    /**
     * @brief Number of FIR taps in this filter stage.
     *
     */
    unsigned num_taps;

    /**
     * @brief Decimation ratio (downsampling factor) applied by this filter stage
     */
    unsigned decimation_factor;

    /**
     * @brief Per-microphone state buffer size in int32_t words.
     * @details
     * Used to index state for each mic: state[mic * state_words_per_channel ... ].
     */
    unsigned state_words_per_channel;
}mic_array_filter_conf_t;

/**
 * @brief Configuration for the full decimator pipeline.
 *
 * Contains an array of stage configurations in execution order.
 * - filter_conf[0] is the first stage (PDM front‑end).
 * - filter_conf[1] is the second stage (PCM FIR decimator).
 */
typedef struct {
    /**
     * @brief Array of filter stage configurations (ordered in filter execution order)
     */
    mic_array_filter_conf_t *filter_conf;

    /**
     * @brief Number of filter stages in the decimation pipeline.
     * @details
     * Specifies the length of @c filter_conf. For a typical two-stage decimator,
     * set this to 2 with @c filter_conf[0] as stage 1 and @c filter_conf[1] as stage 2.
     * Must be >= 1.
     */
    unsigned num_filter_stages;
}mic_array_decimator_conf_t;

/**
 * @brief Configuration for the PDM RX service
 */
typedef struct {
    /**
     * @brief PDM RX output block (input to the decimator) for all microphones.
     * @details
     * Packed PDM samples as 32-bit words. The layout is a contiguous buffer
     * sized `output_mic_count * pdm_out_words_per_channel` 32-bit words, arranged as
     * [output_mic_count][pdm_out_words_per_channel].
     * In the `pdm_out_words_per_channel` 32-bit words, lower indexed words represent older samples.
     * Within a 32-bit word the less significant bits are older samples.
     * Typically contains enough PDM words to produce one PCM sample per microphone
     * after decimation.
     *
     * This buffer must be aligned to a 32-bit word boundary.
     */
    uint32_t *pdm_out_block;
    /**
     * @brief PDM input block (double buffered) for all microphones.
     * @details
     * Packed PDM input samples as 32-bit words.
     * The layout is a contiguous buffer of size `2 * input_mic_count * pdm_out_words_per_channel`
     * 32-bit words, arranged as [2][input_mic_count][pdm_out_words_per_channel].
     * The buffer is double buffered such that one buffer is processed by the
     * decimator while the other is filled by the PDM RX service.
     *
     * This buffer must be aligned to an 8-byte boundary, as required by the
     * deinterleave functions.
     */
    uint32_t *pdm_in_double_buf;

    /**
     * @brief Array mapping `output_mic_count` outputs to input microphone indices.
     * @details
     * Array dimension must be `output_mic_count`.
     * The i<sup>th</sup> entry gives the input mic index mapped to output mic index `i`.
     */
    const unsigned* channel_map;

    /**
     * @brief
     * Number of 32-pdm_sample subblocks to be captured for each microphone channel
     * by the PDM RX service.
     * @details
     * This is the number of words required to produce one PCM sample
     * at the output of the decimator and is sized depending on the decimator configuration.
     * It is typically equal to the 2<sup>nd</sup>
     * stage decimation filter's decimation factor (in case of a 2 stage decimator).
     */
    unsigned pdm_out_words_per_channel; // per channel pdm rx output block (input to the decimator) size
}pdm_rx_conf_t;


/**
 * @brief Top-level configuration passed to mic_array_init_custom_filter().
 * @details
 * Bundles the decimator pipeline configuration and the PDM RX configuration.
 * All buffers referenced by pointers inside these sub-configs must be allocated
 * and owned by the caller and must remain valid for the lifetime of the mic array
 * task (until mic_array_start() returns).
 *
 * @note
 * - When using mic_array_init_custom_filter(), both members must be populated.
 */
typedef struct {
    /** decimator configuration */
    mic_array_decimator_conf_t decimator_conf;
    /** PDM RX service configuration */
    pdm_rx_conf_t pdmrx_conf;
}mic_array_conf_t;

C_API_END

#endif
