#pragma once

#include "api.h"
#include "etc/xcore_compat.h"

#include "xs3_math.h"

#include <stdint.h>


C_API_START


/**
 * @brief Collection of resources required for PDM capture.
 * 
 * This struct contains the xcore resources used for capturing PDM data from a 
 * port.
 * 
 * This struct is used whether the PDM mics are to be used in SDR mode or DDR
 * mode.
 */
MA_C_API
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
#define PDM_RX_RESOURCES_SDR(P_MCLK, P_PDM_CLK, P_PDM_MICS, CLOCK_A)    \
    { (port_t) (P_MCLK), (port_t) (P_PDM_CLK), (port_t) (P_PDM_MICS),   \
      (clock_t) (CLOCK_A) }


/**
 * @brief Initialize a `pdm_rx_resources_t` for DDR mode.
 */
#define PDM_RX_RESOURCES_DDR(P_MCLK, P_PDM_CLK, P_PDM_MICS, CLOCK_A, CLOCK_B) \
    { (port_t) (P_MCLK), (port_t) (P_PDM_CLK), (port_t) (P_PDM_MICS),         \
      (clock_t) (CLOCK_A), (clock_t) (CLOCK_B) }



C_API_END
