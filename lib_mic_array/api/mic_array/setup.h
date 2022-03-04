#pragma once

#include "mic_array.h"

C_API_START

MA_C_API
void mic_array_resources_configure(
    pdm_rx_resources_t* pdm_res,
    int divide);

MA_C_API
void mic_array_pdm_clock_start(
    pdm_rx_resources_t* pdm_res);

static inline
unsigned mic_array_mclk_divider(
  const unsigned master_clock_freq,
  const unsigned pdm_clock_freq);


#include "mic_array/impl/setup_impl.h"

C_API_END