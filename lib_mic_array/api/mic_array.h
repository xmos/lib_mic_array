#pragma once


#define MAX_MIC_COUNT     8

#include "mic_array/types.h"

#include "mic_array/pdm_rx.h"
#include "mic_array/decimator.h"
#include "mic_array/framing.h"
#include "mic_array/frame_transfer.h"
#include "mic_array/misc.h"

#ifdef __XC__
extern "C" {
#endif


static
void mic_array_setup(
    pdm_rx_resources_t* pdm_res,
    int divide);

static
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

static
unsigned mic_array_mclk_divider(
  const unsigned master_clock_freq,
  const unsigned pdm_clock_freq);


#include "mic_array_internal.h"

#ifdef __XC__
}
#endif //__XC__