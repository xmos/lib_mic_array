// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#include "mic_array.h"

C_API_START

/**
 * @brief Configure the hardware resources needed by the mic array.
 * 
 * Several hardware resources are needed to correctly run the mic array, 
 * including 3 ports and 1 or 2 clock blocks (depending on whether SDR or DDR
 * mode is used). This function configures these resources for operation with
 * the mic array.
 * 
 * The `pdm_rx_resources_t` struct is a container for identifying precisely 
 * these resources. All three ports are reset by this function; any existing
 * port configuration will be clobbered.
 * 
 * The parameter `divide` is the ratio of the audio master clock to the desired
 * PDM clock rate. For example, to generate a desired 3.072 MHz PDM clock from 
 * an audio master clock with frequency 24.576 MHz, a `divide` value of 8 is 
 * needed. \verbatim embed:rst
   Divide can also be calculated from the master and PDM clock frequencies using 
   :c:func:`mic_array_mclk_divider()`.\endverbatim
 * 
 * `pdm_res->p_mclk` is the resource ID for the 1-bit port on which the audio
 * master clock is received. This function will enable this port and configure 
 * it as the source port for `pdm_res->clock_a` and for `pdm_res->clock_b` if 
 * operating in a DDR configuration.
 * 
 * `pdm_res->clock_a` is the resource ID for the first (in SDR configuration,
 * the only) clock block required by the mic array. Clock A divides the audio
 * master clock (by a factor of `divide`) to generate the PDM clock. This
 * function enables it with the audio master clock as its source.
 * 
 * `pdm_res->p_pdm_clk` is the resource ID for the 1-bit port from which the PDM
 * clock will be signaled to the microphones. This function enables it and
 * configures Clock A as its source clock.
 * 
 * `pdm_res->clock_b` is the resource ID for a second clock block, which is only 
 * required by the mic array in a DDR configuration. In DDR mode, this function
 * enables Clock B with the audio master clock as its source. The divider for 
 * Clock B is half of that for Clock A (so it runs at twice the frequency). In
 * a DDR configuration Clock B is used as the PDM capture clock. In an SDR
 * configuration, this field must be set to 0 (this is how SDR/DDR is 
 * determined).
 * 
 * `pdm_res->p_pdm_mics` is the resource ID for the port on which PDM data is
 * received. This function enables it and configures it as a 32-bit buffered 
 * input. If operating in an SDR configuration, Clock A is used as the capture 
 * clock. If operating in a DDR configuration, Clock B is used as its capture 
 * clock.
 * 
 * This function only configures and does not start either Clock A or Clock B. 
 * A call to `mic_array_pdm_clock_start()` with `pdm_res` as the argument can be
 * used to start the clock(s).
 * 
 * This function should be called during initialization, before any PDM data can
 * be captured or processed.
 * 
 * @param pdm_res   The hardware resources used by the mic array.
 * @param divide    The divider to generate the PDM clock from the master clock.
 */
MA_C_API
void mic_array_resources_configure(
    pdm_rx_resources_t* pdm_res,
    int divide);

/**
 * @brief Start the PDM and capture clock(s).
 * 
 * This function starts Clock A, and if using a DDR configuration, Clock B.
 * 
 * `mic_array_resources_configure()` must have been called already to configure
 * the resources indicated in `pdm_res`.
 * 
 * Clock A is the PDM clock. Starting Clock A will cause `pdm_res->p_pdm_clk` to 
 * begin strobing the PDM clock to the PDM microphones.
 * 
 * In an SDR configuration, Clock A is also the capture clock. In a DDR 
 * configuration, Clock B is the capture clock. In either case, the capture 
 * clock is also started, causing `pdm_res->p_pdm_mics` to begin storing PDM 
 * samples received on each period of the capture clock.
 * 
 * In DDR configuration, this function starts Clock B, waits for a rising edge, 
 * and then starts Clock A, ensuring that the rising edges of the two clocks are 
 * not in phase.
 * 
 * This function must be called prior to launching the decimator or PDM rx 
 * threads.
 * 
 * @warning Once this function has been called, the port receiving PDM data will 
 * begin capturing samples. If the mic array unit is not started by the time the
 * port buffer fills (`(32/mic_count)` sample times) samples will begin to be
 * dropped.
 * 
 * @param pdm_res   The hardware resources used by the mic array.
 */
MA_C_API
void mic_array_pdm_clock_start(
    pdm_rx_resources_t* pdm_res);

/**
 * @brief Compute clock divider for PDM clock.
 * 
 * This is a convenience function which computes the required clock divider to 
 * derive a `pdm_clock_freq` Hz clock from a `master_clock_freq` Hz clock. This 
 * function is simple integer division.
 * 
 * @param master_clock_freq The master audio clock frequency in Hz.
 * @param pdm_clock_freq    The desired PDM clock frequency in Hz.
 * 
 * @returns Required clock divider.
 */
static inline
unsigned mic_array_mclk_divider(
  const unsigned master_clock_freq,
  const unsigned pdm_clock_freq);


#include "mic_array/impl/setup_impl.h"

C_API_END