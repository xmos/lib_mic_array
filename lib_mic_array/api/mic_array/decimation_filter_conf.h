// Copyright 2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef DECIMATION_FILTER_CONF_H
#define DECIMATION_FILTER_CONF_H

#include <stdint.h>
#include "xmath/xmath.h"

#define MAX_DECIMATION_STAGES (4)

C_API_START

typedef struct
{
    int32_t *coef;
    int32_t * state;
    right_shift_t  shr;
    unsigned num_taps;
    unsigned decimation_factor;
    unsigned state_size; // per channel state size in int32_t words
}mic_array_filter_conf_t;

typedef struct {
    unsigned mic_count;
    mic_array_filter_conf_t filter_conf[MAX_DECIMATION_STAGES];
}mic_array_decimator_conf_t;

typedef struct {
    uint32_t *out_block;
    uint32_t *out_block_double_buf;
    const unsigned* channel_map;
    unsigned out_block_size; // per channel pdm rx output block (input to the decimator) size
    unsigned num_mics;
    unsigned num_mics_in;
}pdm_rx_config_t;

typedef struct {
    uint32_t mic_count;
    mic_array_decimator_conf_t decimator_conf;
    pdm_rx_config_t pdmrx_conf;
}mic_array_conf_t;

C_API_END

#endif
