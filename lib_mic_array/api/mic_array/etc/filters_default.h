// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array/api.h"
#include "xmath/xmath.h"

#include <stdint.h>

/**
 * @defgroup filters_default_h_ filters_default.h
 */

C_API_START

/**
 * Stage 1 PDM-to-PCM Decimation Filter
 * 
 * Decimation Factor:  32  
 * Tap Count: 256
 * 
 * The first stage decimation FIR filter converts 1-bit PDM samples into 32-bit 
 * PCM samples and simultaneously decimates by a factor of 32.
 * 
 * A typical input PDM sample rate will be 3.072M samples/sec, thus the 
 * corresponding output sample rate will be 96k samples/sec.
 * 
 * The first stage filter uses 16-bit coefficients for its taps. Because 
 * this is a highly optimized filter targeting the VPU hardware, the first
 * stage filter is presently restricted to using exactly 256 filter taps.
 * 
 * For more information about the example first stage filter supplied with the 
 * library, including frequency response and steps for using a custom first
 * stage filter, see @beginrst :ref:`decimator_stages` @endrst.
 */

/** 
 * Stage 1 Decimation Factor 
 * 
 * This is the ratio of input sample rate to output sample rate for the first
 * filter stage.
 * 
 * @note In version 5.0 of lib_mic_array, this value is fixed (even if you 
 * choose not to use the default filter coefficients).
 * 
 * @ingroup filters_default_h_
 */
#define STAGE1_DEC_FACTOR   32

/**
 * Stage 1 Filter Tap Count
 * 
 * This is the number of filter taps in the first stage filter.
 * 
 * @note In version 5.0 of lib_mic_array, this value is fixed (even if you 
 * choose not to use the default filter coefficients).
 * 
 * @ingroup filters_default_h_
 */
#define STAGE1_TAP_COUNT    256

/**
 * Stage 1 Filter Word Count
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
 * 
 * 
 * @ingroup filters_default_h_
 */
#define STAGE1_WORDS        (STAGE1_TAP_COUNT)/2

/**
 * Stage 1 PDM-to-PCM Decimation Filter Default Coefficients
 * 
 * These are the default coefficients for the first stage filter.
 * 
 * @ingroup filters_default_h_
 */
extern const uint32_t stage1_coef[STAGE1_WORDS];






/**
 * Stage 2 Decimation Filter
 * 
 * Decimation Factor: (configurable)
 * Tap Count: (configurable)
 * 
 * The second stage decimation FIR filter filters and downsamples the
 * 32-bit PCM output stream from the first stage filter into another
 * 32-bit PCM stream with sample rate reduced by the stage 2 decimation
 * factor.
 * 
 * A typical first stage output sample rate will be 96k samples/sec, a
 * decimation factor of 6 (i.e. using the default stage 2 filter) will
 * mean a second stage output sample rate of 16k samples/sec.
 * 
 * The second stage filter uses 32-bit coefficients for its taps. A
 * complete description of the FIR implementation is outside the scope
 * of this documentation, but it can be found in the `xs3_filter_fir_s32_t`
 * documentation of `lib_xcore_math`.
 * 
 * In brief, the second stage filter coefficients are quantized to a Q1.30 
 * fixed-point format with input samples treated as integers. The tap outputs 
 * are added into a 40-bit accumulator, and an output sample is produced by 
 * applying a rounding arithmetic right-shift to the accumulator and then 
 * clipping the result to the interval `[INT32_MAX, INT32_MIN)`.
 * 
 * For more information about the example second stage filter supplied with the 
 * library, including frequency response and steps for using a custom filter, 
 * see @beginrst :ref:`decimator_stages` @endrst.
 */

/** 
 * Stage 2 Decimation Factor for default filter.
 * 
 * This is the ratio of input sample rate to output sample rate for the second
 * filter stage.
 * 
 * While the second stage filter can be configured with a different decimation
 * factor, this is the one used for the filter supplied with this library.
 * 
 * @ingroup filters_default_h_
 */
#define STAGE2_DEC_FACTOR   6

/**
 * Stage 2 Filter tap count for default filter.
 * 
 * This is the number of filter taps associated with the second stage filter
 * supplied with this library.
 * 
 * @ingroup filters_default_h_
 */
#define STAGE2_TAP_COUNT    65

/**
 * Stage 2 Decimation Filter Default Coefficients
 * 
 * These are the default coefficients for the second stage filter.
 * 
 * @ingroup filters_default_h_
 */
extern const int32_t stage2_coef[STAGE2_TAP_COUNT];

/**
 * Stage 2 Decimation Filter Default Output Shift
 * 
 * This is the non-negative, rounding, arithmetic right-shift applied
 * to the 40-bit accumulator to produce an output sample.
 * 
 * @ingroup filters_default_h_
 */
extern const right_shift_t stage2_shr;

C_API_END
