#pragma once


#define USE_C_VERSION   0

#ifdef __XC__

extern "C" {
// I was having issues just including "xccompat.h" or whatever, so this was a quick fix.
typedef unsigned xclock_t;
typedef unsigned port_t;

#else //__XC__

#include <xs1_user.h>
#include <xcore/clock.h>
#include <xcore/port.h>

#endif //__XC__

#include "pdm_rx.h"
#include "mic_array_filter.h"

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