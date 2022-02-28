#pragma once

#include "xs3_math.h"

#include "etc/xcore_compat.h"

#include <stdint.h>

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif //__XC__


/**
 * @brief Get size requirement for PDM rx buffers.
 * 
 * `pdm_rx_context_t` requires two buffers to store captured PDM data. The 
 * required size for the buffers (when using the provided decimator thread) is 
 * dictated by the microphone count and the stage 2 filter's decimation factor.
 * 
 * @param MIC_COUNT     Number of microphones being captured.
 * @param S2_DEC_FACTOR Stage 2 filter's decimation factor.
 * 
 * @returns Number of _words_ required for _each_ PDM buffer.
 */
#define PDM_RX_BUFFER_SIZE_WORDS(MIC_COUNT, S2_DEC_FACTOR)  ( (MIC_COUNT) *    \
                                                              (S2_DEC_FACTOR) )

/**
 * @brief PDM receive state context.
 * 
 * Holds state information for reading PDM data using `pdm_rx()`.
 */
typedef struct {
  /** 
   * Pointers to 2 buffers used to store received PDM samples.
   * 
   * Each buffer is large enough to store enough PDM samples for each mic 
   * channel to perform both a first and second stage decimation.
   * 
   * Each time a buffer is filled, the pointers are swapped so that the PDM 
   * read logic is always filling one while the decimator processes the other.
   * 
   * @see PDM_RX_BUFFER_SIZE_WORDS
   */
  uint32_t* pdm_buffer[2];
  /** Number of port reads remaining until the current PDM buffer is filled. */
  unsigned phase;
  /** Total number of port reads to fill a PDM buffer, less one. */
  unsigned phase_reset;
} pdm_rx_context_t;


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


/**
 * @brief Construct a `pdm_rx_context_t` object using the supplied paramters.
 * 
 * If the `MA_STATE_DATA()` macro (see @ref `mic_array/decimator.h`) was used to
 * allocate buffers, the buffers for `pdm_buffer_a` and `pdm_buffer_b` will be
 * `&ma_buffers.stage1.pdm_buffers[0][0]` and 
 * `&ma_buffers.stage1.pdm_buffers[1][0]`, where `ma_buffers` is the struct
 * allocated using `MA_STATE_DATA()`.
 */
static inline
pdm_rx_context_t pdm_rx_context(
    uint32_t* pdm_buffer_a,
    uint32_t* pdm_buffer_b,
    const unsigned buffer_words);


/**
 * @brief Initialize the PDM rx ISR context and enable the ISR on the core
 *        on which this function is being called.
 *  
 * When using the PDM rx system in ISR mode the application must choose a core
 * for the ISR to execute on. This function must be called from a thread running
 * on that core before any PDM data can be captured.
 * 
 * Typically this function is called on the core running the decimator thread.
 * 
 * `buffer_words` is the number of PDM port reads that will fill each buffer.
 * `pdm_buffer_a` and `pdm_buffer_b` should each point to a buffer that can 
 * hold `buffer_words` words of data. Typically `buffer_words` will be derived
 * from `PDM_RX_BUFFER_SIZE_WORDS()`.
 * 
 * If the `MA_STATE_DATA()` macro (see @ref `mic_array/decimator.h`) was used to
 * allocate buffers, the buffers for `pdm_buffer_a` and `pdm_buffer_b` will be
 * `&ma_buffers.stage1.pdm_buffers[0][0]` and 
 * `&ma_buffers.stage1.pdm_buffers[1][0]`, where `ma_buffers` is the struct
 * allocated using `MA_STATE_DATA()`.
 * 
 * @note This function does _not_ unmask interrupts on the core. It only sets
 *       up and enables the ISR. `interrupt_unmask_all()` in 
 *      `xcore/interrupt.h` can be called to unmask all interrupts on a core.
 * 
 * @note Calling this function is _not_ necessary if PDM rx is run in thread
 *       mode (see `pdm_rx_task()`) instead of ISR mode. 
 * 
 * @param p_pdm_mics  
 * @param pdm_buffer_a  First PDM sample buffer.
 * @param pdm_buffer_b  Second PDM sample buffer.
 * @param buffer_words  Size of the buffers pointed to by `pdm_buffer_a` and 
 *                      `pdm_buffer_b`, in words
 * @param c_pdm_data    Streaming chanend through which filled PDM buffers will
 *                      be sent to the decimator.
 */
void pdm_rx_isr_enable(
    const port_t p_pdm_mics,
    uint32_t* pdm_buffer_a,
    uint32_t* pdm_buffer_b,
    const unsigned buffer_words,
    const chanend_t c_pdm_data);


/**
 * @brief Receive PDM buffer from PDM rx service.
 * 
 * Blocking function which waits to receive a pointer to a full PDM buffer
 * from the supplied chanend.
 * 
 * If the channel's receive buffer is already full, this function won't block.
 * 
 * `c_pdm_data` must be a _streaming_ chanend.
 * 
 * @param c_pdm_data  Streaming channel from which to receive PDM buffer.
 * 
 * @returns PDM buffer
 */
uint32_t* pdm_rx_buffer_receive(
    const chanend_t c_pdm_data);


/**
 * @brief Send PDM buffer from PDM rx service.
 * 
 * Function sends the `pdm_buffer` pointer over the `c_pdm_data` chanend.
 * 
 * If the transmit buffer for `c_pdm_data` is full, this function will block
 * until it isn't full.
 * 
 * `c_pdm_data` must be a _streaming_ chanend.
 * 
 * @param c_pdm_data  Streaming channel over which to send PDM buffer.
 * @param pdm_buffer  PDM buffer to send.
 */
void pdm_rx_buffer_send(
    const chanend_t c_pdm_data,
    const uint32_t* pdm_buffer);


/**
 * @brief PDM Receive Thread
 * 
 * This function loops forever (does not return) collecting PDM samples from
 * `p_pdm_mics` and sending full buffers over `c_pdm_data`.
 * 
 * `c_pdm_data` must be a _streaming_ chanend.
 * 
 * @param p_pdm_mics  Port from which to read PDM data.
 * @param context     Initialized PDM rx context.
 * @param c_pdm_data  Streaming channel over which to send PDM buffers.
 */
void pdm_rx_task(
    port_t p_pdm_mics,
    pdm_rx_context_t context,
    chanend_t c_pdm_data);



#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__


#include "impl/pdm_rx_impl.h"