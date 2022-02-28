#pragma once


#define MAX_MIC_COUNT     8

#include "mic_array/types.h"
#include "mic_array/pdm_rx.h"
#include "mic_array/decimator.h"
#include "mic_array/dc_elimination.h"
#include "mic_array/framing.h"
#include "mic_array/frame_transfer.h"

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif


static inline
void mic_array_setup(
    pdm_rx_resources_t* pdm_res,
    int divide);

static inline
void mic_array_start(
    pdm_rx_resources_t* pdm_res);

void mic_array_setup_sdr(
    pdm_rx_resources_t* pdm_res,
    int divide);

void mic_array_start_sdr(
    pdm_rx_resources_t* pdm_res);

void mic_array_setup_ddr(
    pdm_rx_resources_t* pdm_res,
    int divide);

void mic_array_start_ddr(
    pdm_rx_resources_t* pdm_res);

static inline
unsigned mic_array_mclk_divider(
  const unsigned master_clock_freq,
  const unsigned pdm_clock_freq);


#include "mic_array/impl/mic_array_impl.h"

#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__