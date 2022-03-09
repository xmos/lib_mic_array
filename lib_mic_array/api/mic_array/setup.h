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
 * The parameter `divide` is the ratio of the audio master clock to the desired
 * PDM clock rate. E.g. to generate a 3.072 MHz PDM clock from an audio master
 * clock with frequency 24.576 MHz, a `divide` value of 8 is needed. Divide can
 * also be calculated from the master and PDM clock frequencies using
 * `mic_array_mclk_divider()`.
 * 
 * `pdm_res->p_mclk` is the resource ID for the 1-bit port on which the audio
 * master clock is received. This port is enabled and configured as the source
 * port for `pdm_res->clock_a` and for `pdm_res->clock_b` if in DDR mode.
 * 
 * `pdm_res->clock_a` is the resource ID for the first (and in SDR mode, only) 
 * clock block required by the mic array. Clock A divides the audio master clock 
 * (by a factor of `divide`) to generate the PDM clock. It is enabled with the
 * audio master clock as its source.
 * 
 * `pdm_res->p_pdm_clk` is the resource ID for the 1-bit port from which the PDM
 * clock will be signaled to the microphones. It is enabled and configured with
 * Clock A as its source clock.
 * 
 * `pdm_res->clock_b` is the resource ID for a second clock block, which is 
 * required by the mic array when operating in DDR mode only. In DDR mode, Clock
 * B is enabled with the audio master clock as its source. The divider for 
 * Clock B is half of that for Clock A (so it runs at twice the frequency). In
 * DDR mode Clock B used as the PDM capture clock. If operating in SDR mode, 
 * this field should be set to 0 (Indeed, this is how SDR/DDR is determined).
 * 
 * `pdm_res->p_pdm_mics` is the resource ID for the port on which PDM data is
 * received. It is enabled and configured as a 32-bit buffered input. If 
 * operating in SDR mode, Clock A is used as the capture clock. If operating in
 * DDR mode, Clock B is used as its capture clock.
 * 
 * This function only configures and does not start either Clock A or Clock B. 
 * A call to `mic_array_pdm_clock_start()` with `pdm_res` as the argument can be
 * used to start the clock(s).
 * 
 * This function must be called during initialization, before any PDM data can
 * be captured or processed.
 * 
 * @note If using the 'vanilla' API (see @todo), this will be called for you 
 *       during mic array initialization.
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
 * This function starts Clock A, and if using DDR mode, Clock B.
 * 
 * `mic_array_resources_configure()` must have been called already to configure
 * the resources indicated in `pdm_res`.
 * 
 * Clock A is the PDM clock. Starting Clock A will cause `pdm_res->p_pdm_clk` to 
 * begin strobing the PDM clock to the PDM microphones.
 * 
 * In SDR mode, Clock A is also the capture clock. In DDR mode, Clock B is the
 * capture clock. In either case, the capture clock is also started, causing 
 * `pdm_res->p_pdm_mics` to begin storing PDM samples received on each period
 * of the capture clock.
 * 
 * If in DDR mode, this function starts Clock B, waits for a rising edge, and
 * then starts Clock A, ensuring that the rising edges of the two clocks are not
 * in phase.
 * 
 * This function must be called prior to launching the decimator or PDM rx 
 * threads.
 * 
 * @note If using the 'vanilla' API (see @todo), this will be called for you 
 *       when the mic array's decimator thread is started.
 * 
 * @param pdm_res   The hardware resources used by the mic array.
 */
MA_C_API
void mic_array_pdm_clock_start(
    pdm_rx_resources_t* pdm_res);

/**
 * @brief Compute clock divider.
 * 
 * This function computes the required clock divider to derive a 
 * `pdm_clock_freq` Hz clock from a `master_clock_freq` Hz clock. This function
 * assumes `master_clock_freq` is an integer multiple of `pdm_clock_freq`.
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