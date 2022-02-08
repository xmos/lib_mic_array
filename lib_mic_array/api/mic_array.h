#pragma once


#define MAX_MIC_COUNT     8


#include "xcore_compat.h"

#include "pdm_rx.h"
#include "pdm_filter_task.h"
#include "mic_array_filter.h"
#include "mic_array_framing.h"
#include "mic_array_misc.h"

#ifdef __XC__
extern "C" {
#endif

void mic_array_setup_sdr(
        xclock_t pdmclk,
        port_t p_mclk,
        port_t p_pdm_clk,
        port_t p_pdm_mics,
        int divide);

void mic_array_start_sdr(
        xclock_t pdmclk);

void mic_array_setup_ddr(
        xclock_t pdmclk,
        xclock_t pdmclk6,
        port_t p_mclk,
        port_t p_pdm_clk,
        port_t p_pdm_mics,
        int divide);

void mic_array_start_ddr(
        xclock_t pdmclk,
        xclock_t pdmclk6,
        port_t p_pdm_mics);



#ifdef __XC__
}
#endif //__XC__