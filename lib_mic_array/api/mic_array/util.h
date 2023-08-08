// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <stdint.h>

#include "api.h"
C_API_START

/**
 * @brief Perform deinterleaving for a 2-microphone subblock.
 * 
 * Assembly function. 
 * 
 * Deinterleave the samples for 1 subblock of 2 microphones. Argument points to
 * a 2 word buffer.
 */
MA_C_API 
void deinterleave2(uint32_t*);


/**
 * @brief Perform deinterleaving for a 4-microphone subblock.
 * 
 * Assembly function. 
 * 
 * Deinterleave the samples for 1 subblock of 4 microphones. Argument points to
 * a 4 word buffer.
 */
MA_C_API 
void deinterleave4(uint32_t*);


/**
 * @brief Perform deinterleaving for a 8-microphone subblock.
 * 
 * Assembly function. 
 * 
 * Deinterleave the samples for 1 subblock of 8 microphones. Argument points to
 * a 8 word buffer.
 */
MA_C_API 
void deinterleave8(uint32_t*);


/**
 * @brief Perform deinterleaving for a 16-microphone subblock.
 * 
 * Assembly function. 
 * 
 * Deinterleave the samples for 1 subblock of 16 microphones. Argument points to
 * a 16 word buffer.
 * 
 * @ingroup util_h_
 */
MA_C_API 
void deinterleave16(uint32_t*);

C_API_END