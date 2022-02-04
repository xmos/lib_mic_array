#pragma once

#include "xs3_math.h"

#include "xcore_compat.h"
#include "mic_array.h"

#include <stdint.h>

#ifdef __XC__
extern "C" {
#endif //__XC__


#define MA_PDM_BUFFER_SIZE_WORDS(MIC_COUNT, S2_DEC_FACTOR)  ( (MIC_COUNT) * (S2_DEC_FACTOR) )

/**
 * This struct models the memory allocated in `pdm_rx_isr.S` used for
 * the PDM receive ISR.
 */
typedef struct {
  port_t p_pdm_data;
  uint32_t* pdm_buffer[2];
  unsigned phase;
  unsigned phase_reset;
  streaming_channel_t c_pdm_data;
} pdm_rx_isr_context_t;



/**
 * Initialize the context data for the PDM rx ISR.
 * 
 * This function sets up the structure used by the PDM rx ISR. It does not actually
 * set up the ISR associated with the receive port.
 * 
 * In most cases MA_PDM_BUFFER_SIZE_WORDS() can be used to determine the appropriate 
 * size for each PDM buffer.
 */
chanend_t ma_pdm_rx_isr_init(
  const port_t p_pdm_data,
  uint32_t* pdm_buffer_a,
  uint32_t* pdm_buffer_b,
  const unsigned buffer_words);


/**
 * Loads and enables the ISR vector for the PDM data port.
 * 
 * Does not unmask interrupts.
 */
void ma_pdm_rx_isr_enable(
  const port_t p_pdm_data);



void ma_pdm_rx_task(
  pdm_rx_isr_context_t* context);


#ifdef __XC__
}
#endif //__XC__