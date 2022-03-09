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
 * An object of this type will be required for initializing and starting the 
 * mic array.
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
   * In SDR mode this is also the PDM data capture clock.
   */
  clock_t clock_a;

  /**
   * Clock block used only in DDR mode to trigger reads of the PDM data.
   * 
   * A value of `0` here indicates SDR mode.
   */
  clock_t clock_b;
} pdm_rx_resources_t;


/**
 * @brief Construct a `pdm_rx_resources_t` for SDR mode.
 *
 * `pdm_rx_resources_t.clock_b` is initialized to `0`, indicating SDR mode.
 * 
 * @param P_MCLK      Master audio clock port.
 * @param P_PDM_CLK   PDM clock port.
 * @param P_PDM_MICS  PDM microphone data port.
 * @param CLOCK_A     PDM clock and capture clock block.
 */
#define PDM_RX_RESOURCES_SDR(P_MCLK, P_PDM_CLK, P_PDM_MICS, CLOCK_A)    \
    { (port_t) (P_MCLK), (port_t) (P_PDM_CLK), (port_t) (P_PDM_MICS),   \
      (clock_t) (CLOCK_A) }


/**
 * @brief Construct a `pdm_rx_resources_t` for DDR mode.
 * 
 * @param P_MCLK      Master audio clock port.
 * @param P_PDM_CLK   PDM clock port.
 * @param P_PDM_MICS  PDM microphone data port.
 * @param CLOCK_A     PDM clock clock block.
 * @param CLOCK_B     PDM capture clock block.
 */
#define PDM_RX_RESOURCES_DDR(P_MCLK, P_PDM_CLK, P_PDM_MICS, CLOCK_A, CLOCK_B) \
    { (port_t) (P_MCLK), (port_t) (P_PDM_CLK), (port_t) (P_PDM_MICS),         \
      (clock_t) (CLOCK_A), (clock_t) (CLOCK_B) }



C_API_END
