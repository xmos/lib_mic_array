// Copyright 2021-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <stdint.h>

#include "mic_array/api.h"

C_API_START

/** Function that computes an FIR over a 1-bit signal with 16-bit coefficients.
 * The one-bit signal is stored as a sequence of bits, each of them representing
 * -1 or +1. The coefficients are notionally a vector of 16-bti values, but with
 * a few provisos:
 *
 *   * The number of coefficients must be a multiple of 256, and N_256 (the third
 *     parameter) represents how many multiples there are. N must be at least 1
 *
 *   * The coefficients shall be in the range [-32767 .. 32767]
 *
 *   * Coefficients are stored in slices of bits. A slice of the coefficient vector
 *     comprises 256 coefficients, so there are N_256 slices. 
 *     Each slice occupies 256 * 16 / 32 = 128 words: 16 bits for each of the 256
 *     elements, and there are 23 bits per word. The coefficients are decomposed
 *     over the words, and each group of eight words (256 bits) store subsequent
 *     bits of the coefficients values as follows. The bits in
 *       - words 0..7 have magnitude +/-1
 *       - words 8..15 have magnitude +/-2
 *       - ...
 *       - words 112..119 have magnitude +/-16384, and finally
 *       - words 120..127 have magnitude +/-32767: note that this is not 32768.
 *     0 means +1, +2, +16384, etc, 1 means -1, -2, -16384 etc.
 *
 * Signal and coeff_1 must be word-aligned (hence the data type)
 * the function returns the inner product of the signal with the coefficients in
 * approximately 20 + N_256 * 20 thread-cycles. A 100 MHz thread can
 *
 *   * 32x decimate with a 256-point FIR an 80 MHz PDM signal.
 *   * 32x decimate with a 512-point FIR an 40 MHz PDM signal.
 *   * 64x decimate with a 512-point FIR an 80 MHz PDM signal.
 *
 * @param    signal     the 1-bit signal (32-bit aligned)
 * @param    coeff_1    16-bit coefficients split as above (32-bit aligned)
 *
 * @returns  The inner product
 */
MA_C_API
int fir_1x16_bit(uint32_t signal[], const uint32_t coeff_1[]);

C_API_END