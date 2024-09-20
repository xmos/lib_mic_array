// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <stdint.h>
#include "mic_array/etc/fir_1x16_bit.h"

/**
 * @brief Performs the decimation process in multiple tasks.
 *
 * Each subtask handles a subset of the MICs.
 *
 * @param num_mics The total number of microphones in the array to be processed by the subtask(s).
 * @param s1_hist Stage 1 PDM history.
 * @param s1_filter_coef State 1 filter coefficients.
 * @param s2_dec_factor Stage 2 decimation factor.
 * @param s2_filters Stage 2 FIR filters.
 * @param pdm_block PDM data to be processed.
 * @param sample_out Output sample vector.
 */
extern "C" void decimator_subtask_run(
        const unsigned num_mics,
        uint32_t* s1_hist, const uint32_t* s1_filter_coef,
        const unsigned s2_dec_factor, filter_fir_s32_t* s2_filters,
        uint32_t* pdm_block, int32_t* sample_out);
