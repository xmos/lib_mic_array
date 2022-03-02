#pragma once

#include "xs3_math.h"

#include "etc/xcore_compat.h"

#include <stdint.h>

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif //__XC__


/**
 * @brief Collection of resources required for PDM capture.
 * 
 * This struct contains the xcore resources used for capturing PDM data from a 
 * port.
 * 
 * This struct is used whether the PDM mics are to be used in SDR mode or DDR
 * mode.
 */
typedef struct {
  /** 
   * 1-bit (input) port on which the master audio clock signal is received. 
   */
  port_t p_mclk;
  /** 
   * 1-bit (output) port through which the PDM clock is signaled. 
   */
  port_t p_pdm_clk;
  /** 
   * 1-bit word-buffered (input) port on which PDM samples are received.
   * 
   * @note Due to constraints on available hardware, only 1-bit ports have been
   *       tested. This is a temporary restriction.
   */
  port_t p_pdm_mics;
  /**
   * Clock block used to derive the PDM clock from the master audio clock.
   * 
   * In SDR mode this clock also triggers reads of the PDM data.
   */
  clock_t clock_a;
  /**
   * Clock block used only in DDR mode to trigger reads of the PDM data.
   * 
   * In SDR mode this should be `0`.
   */
  clock_t clock_b;
} pdm_rx_resources_t;


/**
 * @brief Initialize a `pdm_rx_resources_t` for SDR mode.
 *
 * `pdm_rx_resources_t.clock_b` is initialized to `0`, indicating SDR mode.
 */
static inline
pdm_rx_resources_t pdm_rx_resources_sdr(
    port_t p_mclk,
    port_t p_pdm_clk,
    port_t p_pdm_mics,
    clock_t clock_a);


/**
 * @brief Initialize a `pdm_rx_resources_t` for DDR mode.
 */
static inline
pdm_rx_resources_t pdm_rx_resources_ddr(
    port_t p_mclk,
    port_t p_pdm_clk,
    port_t p_pdm_mics,
    clock_t clock_a,
    clock_t clock_b);



/**
 * @brief Determine whether the specified `pdm_rx_resources_t` indicates SDR
 *        or DDR mode.
 * 
 * DDR mode is indicated if `pdm_res->clock_b` is `0`.
 * 
 * @param pdm_res Initialized PDM resources struct.
 * 
 * @returns non-zero iff `pdm_res` indicates DDR mode.
 */
static inline
unsigned pdm_rx_uses_ddr(
    pdm_rx_resources_t* pdm_res);


#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__


#include "impl/pdm_rx_impl.h"