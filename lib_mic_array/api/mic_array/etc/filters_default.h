// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array/api.h"
#include "xmath/xmath.h"

#include <stdint.h>

C_API_START

/** 
 * @brief Macro indicating Stage 1 Decimation Factor 
 * 
 * This is the ratio of input sample rate to output sample rate for the first
 * filter stage.
 * 
 * @note In version 5.0 of lib_mic_array, this value is fixed (even if you 
 * choose not to use the default filter coefficients).
 */
#define STAGE1_DEC_FACTOR   32

/**
 * @brief Macro indicating Stage 1 Filter Tap Count
 * 
 * This is the number of filter taps in the first stage filter.
 * 
 * @note In version 5.0 of lib_mic_array, this value is fixed (even if you 
 * choose not to use the default filter coefficients).
 */
#define STAGE1_TAP_COUNT    256

/**
 * @brief Macro indicating Stage 1 Filter Word Count
 * 
 * This is a helper macro to indicate the number of 32-bit words required to 
 * store the filter coefficients.
 * 
 * @note Even though the coefficients are 16-bit, the related lib_mic_array
 * structs and functions expect them to be contained in an array of `uint32_t`,
 * rather than an array of `int16_t`. There are two reasons for this. 
 * The first is that the VPU instructions require loaded data to start at a 
 * word-aligned (0 mod 4) address. `uint32_t` allocated on the heap or stack 
 * are guaranteed by the compiler to be at word-aligned addresses. 
 * The second reason is to mitigate possible confusion regarding the arrangement 
 * of the filter coefficients in memory. Not only are the 16-bit coefficients not 
 * stored in order (e.g. `b[0], b[1], b[2], ...`), the bits of individual 16-bit 
 * coefficients are not stored together in memory. This is, again, due to the 
 * behavior of the VPU hardware.
 */
#define STAGE1_WORDS        (STAGE1_TAP_COUNT)/2

/**
 * @brief Stage 1 PDM-to-PCM Decimation Filter Default Coefficients
 * 
 * These are the default coefficients for the first stage filter.
 */
extern const uint32_t stage1_coef[STAGE1_WORDS];





/** 
 * @brief Stage 2 Decimation Factor for default filter.
 * 
 * This is the ratio of input sample rate to output sample rate for the second
 * filter stage.
 * 
 * While the second stage filter can be configured with a different decimation
 * factor, this is the one used for the filter supplied with this library.
 */
#define STAGE2_DEC_FACTOR   6

/**
 * @brief Stage 2 Filter tap count for default filter.
 * 
 * This is the number of filter taps associated with the second stage filter
 * supplied with this library.
 */
#define STAGE2_TAP_COUNT    65

/**
 * @brief Stage 2 Decimation Filter Default Coefficients
 * 
 * These are the default coefficients for the second stage filter.
 */
extern const int32_t stage2_coef[STAGE2_TAP_COUNT];

/**
 * @brief Stage 2 Decimation Filter Default Output Shift
 * 
 * This is the non-negative, rounding, arithmetic right-shift applied
 * to the 40-bit accumulator to produce an output sample.
 */
extern const right_shift_t stage2_shr;

C_API_END
