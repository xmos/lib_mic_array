#pragma once


#ifdef __XC__

extern "C" {

typedef unsigned xclock_t;
typedef unsigned port_t;

#else //__XC__

#include <xs1_user.h>
#include <xcore/clock.h>
#include <xcore/port.h>

#endif //__XC__

#include "pdm_rx.h"

extern unsigned pcm_sample_count;
extern unsigned pdm_sample_count;

void mic_array_setup_sdr(
        xclock_t pdmclk,
        port_t p_mclk,
        port_t p_pdm_clk,
        port_t p_pdm_mics,
        int divide);

void mic_array_setup_ddr(
        xclock_t pdmclk,
        xclock_t pdmclk6,
        port_t p_mclk,
        port_t p_pdm_clk,
        port_t p_pdm_mics,
        int divide);

void mic_array_pdm_rx_isr_init(
    ma_pdm_rx_context_t* context,
    const unsigned mic_count,
    const port_t p_pdm_mics,
    const int16_t* stage1_fir_coef,
    const unsigned stage1_fir_coef_blocks,
    const unsigned stage2_decimation_factor,
    ma_pdm_buffer_t* pdm_buffer,
    int32_t* pcm_buffer);


#ifdef __XC__
}
#endif //__XC__