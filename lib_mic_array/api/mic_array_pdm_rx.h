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
  uint32_t* pdm_buffer[2];
  unsigned phase;
  unsigned phase_reset;
} ma_pdm_rx_context_t;


/**
 * Construct a ma_pdm_rx_context_t object using the supplied paramters.
 * 
 * @note This function allocates one of the finite number of streamings channels available 
 *       on the device. It is the caller's responsibility to deallocate the streaming 
 *       channel if and when necessary. 
 * 
 */
ma_pdm_rx_context_t ma_pdm_rx_context_create(
    uint32_t* pdm_buffer_a,
    uint32_t* pdm_buffer_b,
    const unsigned buffer_words);



/**
 * Initializes the PDM rx ISR context and enables the ISR on the core
 * calling this function.
 *  
 * Does not unmask interrupts.
 * 
 * @returns chanend through which filled PDM buffers can be received.
 */
void ma_pdm_rx_isr_enable(
    const port_t p_pdm_mics,
    uint32_t* pdm_buffer_a,
    uint32_t* pdm_buffer_b,
    const unsigned buffer_words,
    const chanend_t c_pdm_data);


/**
 * Blocking function which waits to receive a pointer to a full PDM buffer
 * from the supplied chanend.
 * 
 * If the channel's receive buffer is already full, this function won't block.
 * 
 * `c_pdm_data_in` must be a *streaming* chanend.
 * 
 * @todo: Inline function?
 * 
 * Dev note: This is (currently) a simple channel read, but encapsulating it in a function
 *           to hide that implementation detail, and because options may be added later.
 */
uint32_t* ma_pdm_rx_buffer_receive(
    const chanend_t c_pdm_data);


/**
 * Function sends the `pdm_buffer` pointer over the `c_pdm_data_out` chanend.
 * 
 * If the transmit buffer for `c_pdm_data_out` is full, this function will block
 * until it isn't full.
 * 
 * `c_pdm_data_out` must be a *streaming* chanend.
 * 
 * @todo: Inline function?
 * 
 * Dev note: This is (currently) a simple channel write, but encapsulating it in a function
 *           to hide that implementation detail, and because options may be added later.
 */
void ma_pdm_rx_buffer_send(
    const chanend_t c_pdm_data_out,
    const uint32_t* pdm_buffer);


/**
 * Task for receiving PDM data via a port.
 * 
 * Two buffers are kept. Once one is filled, the buffers are swapped and the address 
 * of the filled buffer is transmitted over a streaming channel.
 */
void ma_pdm_rx_task(
    port_t p_pdm_mics,
    ma_pdm_rx_context_t context,
    chanend_t c_pdm_data);


#ifdef __XC__
}
#endif //__XC__