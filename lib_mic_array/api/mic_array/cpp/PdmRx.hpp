// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <cstdint>
#include <string>
#include <cassert>

#include <xcore/interrupt.h>
#include <xcore/channel_streaming.h>
#include <xcore/port.h>
#include <xcore/select.h>

#include "mic_array.h"
#include "Util.hpp"

// This has caused problems previously, so just catch the problems here.
#if defined(CHANNELS_IN) || defined(CHANNELS_OUT)
# error Application must not define the following as precompiler macros: CHANNELS_IN, CHANNELS_OUT.
#endif

using namespace std;
extern "C" {

  /**
   * @brief PDM rx interrupt configuration and context.
   */
  typedef struct {

    /**
     * Port on which PDM samples are received.
     */
    port_t p_pdm_mics;

    /**
     * Pointers to a pair of buffers used for storing captured PDM samples.
     *
     * The buffers themselves are allocated by the application and passed to
     * @ref mic_array::StandardPdmRxService::Init
     * The idea is that while the PDM rx ISR is filling
     * one buffer, the decimation thread is busy processing the contents of the
     * other buffer. If the real-time constraint is maintained, the decimation
     * thread will be finished with the contents of its buffer before the PDM rx
     * ISR fills the other buffer. Once full, the PDM rx ISR does a double
     * buffer pointer swap and hands the newly-filled buffer to the decimation
     * thread.
     */
    uint32_t* pdm_buffer[2];

    /**
     * Tracks the completeness of the buffer currently being filled.
     *
     * Each read of samples from `p_pdm_mics` gives one word of data. This
     * variable tracks how many more port reads are required before the current
     * buffer has been filled.
     */
    unsigned phase;

    /**
     * The number of words to read from `p_pdn_mics` to fill a buffer.
     */
    unsigned phase_reset;

    /**
     * Streaming chanend the PDM rx ISR uses to signal the decimation thread
     * that another buffer is full and ready to be processed.
     *
     * The streaming channel itself is allocated by @ref
     * mic_array::StandardPdmRxService, which owns the other end of the channel.
     */
    chanend_t c_pdm_data;

    /**
     * Used for detecting when the real-time constraint is violated by the
     * decimation thread.
     *
     * Each time the decimation thread is given a block of PDM data to process,
     * `credit` is reset to `2`. Each time the PDM rx ISR hands a block of PDM
     * data to the decimation thread, this is decremented.
     *
     * @par Deadlock Condition
     * @parblock
     * @ref mic_array::StandardPdmRxService uses a streaming channel to
     * facilitate communication between the two execution contexts used by the
     * mic array, the decimation thread and the PDM rx ISR. A streaming channel
     * is used because it allows the contexts to operate asynchronously.
     *
     * A channel has a 2 word buffer, and as long as there is room in the
     * buffer, an `OUT` instruction putting a word (in this case, a pointer)
     * into the channel is guaranteed not to block. This is important because
     * the PDM rx ISR is typically configured on the same hardware thread as the
     * decimation thread.
     *
     * If a thread is blocked on an `OUT` instruction to a channel, in order to
     * unblock the thread, an `IN` must be issued on the other end of that
     * channel. But because the PDM rx ISR is blocked, it cannot hand control
     * back to the decimation thread, which means the decimation thread can
     * never issue an `IN` instruction to unblock the ISR. The result is a
     * deadlock.
     *
     * Unfortunately, there is no way for a thread to query a chanend to
     * determine whether it will block if an `OUT` instruction is issued. That
     * is why `credit` is used. Before issuing an `OUT` to `c_pdm_data`, the PDM
     * rx ISR checks whether `credit` is non-zero. If so, the ISR issues the
     * `OUT` instruction as normal and decrements `credit`.
     *
     * If `credit` is zero, the default behavior of PDM rx ISR is to raise an
     * exception (`ET_ECALL`). This reflects the idea that it is generally
     * better if system-breaking errors loudly announce themselves (at least by
     * default). If using @ref mic_array::StandardPdmRxService, this behavior
     * can be changed by passing `false` in a call to
     * @ref mic_array::StandardPdmRxService::AssertOnDroppedBlock(), which will
     * allow blocks of PDM data to be silently dropped (while still avoiding a
     * permanent deadlock).
     * @endparblock
     */
    unsigned credit;

    /**
     * Controls and records anti-deadlock behavior.
     *
     * If the PDM rx ISR finds that `credit` is `0` when it's time to send a
     * filled buffer to the decimation thread, it uses `missed_blocks` to
     * control whether the PDM rx ISR should raise an exception or silently drop
     * the block of PDM data.
     *
     * If `missed_blocks` is `-1` (its default value) an exception is raised.
     * Otherwise `missed_blocks` is used to record the number of blocks that
     * have been quietly dropped.
     */
    unsigned missed_blocks;
  } pdm_rx_isr_context_t;

  /**
   * Configuration and context of the PDM rx ISR when @ref
   * mic_array::StandardPdmRxService is used in interrupt mode.
   *
   * `pdm_rx_isr` (`pdm_rx_isr.S`) directly allocates this object as
   * configuration and state parameters required by that interrupt routine.
   */
  extern pdm_rx_isr_context_t pdm_rx_isr_context;

  /**
   * @brief Configure port to use `pdm_rx_isr` as an interrupt routine.
   *
   * This function configures `p_pdm_mics` to use `pdm_rx_isr` as its interrupt
   * vector and enables the interrupt on the current hardware thread.
   *
   * This function does NOT unmask interrupts.
   *
   * @param p_pdm_mics Port resource to enable ISR on.
   */
  static inline
  void enable_pdm_rx_isr(
      const port_t p_pdm_mics)
  {
    #if defined(__XS3A__)
    asm volatile(
      "setc res[%0], %1       \n"
      "ldap r11, pdm_rx_isr   \n"
      "setv res[%0], r11      \n"
      "eeu res[%0]              "
        :
        : "r"(p_pdm_mics), "r"(XS1_SETC_IE_MODE_INTERRUPT)
        : "r11" );
    #endif // __XS3A__
  }

}


namespace  mic_array {
  /**
   * @brief PDM rx service which collects PDM sample data from a port
   * and uses a streaming channel to send a block of data by pointer further
   * down the mic array pipeline.
   *
   * This class template is intended to be used for the `TPdmRx`
   * template parameter of @ref MicArray, where it represents the @ref
   * MicArray::PdmRx component of the mic array.
   *
   * This class can run the PDM rx service either as a stand-alone thread or
   * through an interrupt.
   *
   * @par Inter-context Transfer
   * @parblock
   * A streaming channel is used to transfer control of the PDM data block
   * between execution contexts (i.e. thread->thread or ISR->thread).
   *
   * The mic array unit receives blocks of PDM data from an instance of this
   * class by calling @ref GetPdmBlock(), which blocks until a new PDM block is
   * available.
   * @endparblock
   *
   * `StandardPdmRxService` collects blocks of PDM samples from a
   * port and makes them available to the decimation thread as the blocks are
   * completed.
   *
   * This class provides the logic for aggregating PDM data taken from
   * a port into blocks, and provides methods
   * `ReadPort()`, `SendBlock()` and `GetPdmBlock()`.
   *
   * `ReadPort()` is responsible for reading 1 word of data from
   * `p_pdm_mics`.
   *
   * `SendBlock()` is provided a block of PDM data as a pointer and is
   * responsible for signaling that to the subsequent processing stage.
   *
   * `ReadPort()` and `SendBlock()` are used by `StandardPdmRxService` itself (when
   * running as a thread, rather than ISR).
   *
   * `GetPdmBlock()` is responsible for receiving a block of PDM data from
   * `SendBlock()` as a pointer, deinterleaving the buffer contents,
   * and returning a pointer to the PDM data in the format expected by the mic
   * array unit's decimator component. See
   *
   * `GetPdmBlock()` is called by the decimation thread. The pair of functions,
   * `SendBlock()` and `GetPdmBlock()` facilitate inter-thread communication,
   * `SendBlock()` being called by the transmitting end of the communication
   * channel, and `GetPdmBlock()` being called by the receiving end.
   *
   * @par Layouts
   * @parblock
   * The buffer transferred by `SendBlock()` contains `CHANNELS_IN * this->pdm_out_words_per_channel`
   * words of PDM data for `CHANNELS_IN` microphone channels. The words are
   * stored in reverse order of arrival. \verbatim embed:rst
     See :cpp:func:`mic_array::deinterleave_pdm_samples` for additional details
     on this format.\endverbatim
   *
   * Within `GetPdmBlock()` (i.e. mic array thread) the PDM data block is
   * deinterleaved and copied to another buffer in the format required by the
   * decimator component, which is returned by `GetPdmBlock()`. This buffer
   * contains `CHANNELS_OUT * this->pdm_out_words_per_channel` words for
   * `CHANNELS_OUT` microphone channels.
   * @endparblock
   *
   *    * @par Channel Filtering
   * @parblock
   * In some cases an application may be required to capture more microphone
   * channels than should actually be processed by subsequent processing stages
   * (including the decimator component). For example, this may be the case if 4
   * microphone channels are desired but only an 8 bit wide port is physically
   * available to capture the samples.
   *
   * This class template has a parameter both for the number of channels to be
   * captured by the port (`CHANNELS_IN`), as well as for the number of channels
   * that are to be output for consumption by the `MicArray`'s decimator
   * component (`CHANNELS_OUT`).
   *
   * When the PDM microphones are in an SDR configuration, `CHANNELS_IN` must be
   * the width (in bits) of the XCore port to which the microphones are
   * physically connected. When in a DDR configuration, `CHANNELS_IN` must be
   * twice the width (in bits) of the XCore port to which the microphones are
   * physically connected.
   *
   * `CHANNELS_OUT` is the number of microphone channels to be consumed by the
   * mic array's decimator component (i.e. must be the same as the `MIC_COUNT`
   * template parameter of the decimator component). If all port pins are
   * connected to microphones, this parameter will generally be the same as
   * `CHANNELS_IN`.
   * @endparblock
   *
   * @par Channel Index (Re-)Mapping
   * @parblock
   *
   * The input channel index of a microphone depends on the pin to which it is
   * connected. Each pin connected to a port has a bit index for that port,
   * given in the 'Signal Description and GPIO' section of your package's
   * datasheet.
   *
   * Suppose an `N`-bit port is used to capture microphone data, and a
   * microphone is connected to bit `B` of that port.  In an SDR microphone
   * configuration, the input channel index of that microphone is `B`, the
   * same as the port bit index.
   *
   * In a DDR configuration, that microphone will be on either input channel
   * index `B` or `B+N`, depending on whether that microphone is configured for
   * in-phase capture or out-of-phase capture.
   *
   * Sometimes it may be desirable to re-order the microphone channel indices.
   * This is likely the case, for example, when `CHANNELS_IN > CHANNELS_OUT`.
   *
   * By default output channels are mapped from the input channels with the same
   * index. If `CHANNELS_IN > CHANNELS_OUT`, this means that the input channels
   * with the highest `CHANNELS_IN-CHANNELS_OUT` indices are dropped by default.
   *
   * The `MapChannel()` and `MapChannels()` methods can be used to specify a
   * non-default mapping from input channel indices to output channel indices.
   * It takes a pointer to a `CHANNELS_OUT`-element array specifying the input
   * channel index for each output channel.
   * @endparblock
   *
   *
   * @tparam CHANNELS_IN  The number of microphone channels to be captured by
   * the port. For example, if using a 4-bit port to capture 6 microphone
   * channels in a DDR configuration (because there are no 3 or 6 pin ports)
   * `CHANNELS_IN` should be ``8``, because that's how many must be captured,
   * even if two of them are stripped out before passing audio frames to
   * subsequent application stages.
   * @tparam CHANNELS_OUT The number of output microphone channels to be delivered by
   *                      this `StandardPdmRxService` instance.
   */
  template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
  class StandardPdmRxService
  {
    private:
      /**
       * @brief Port from which to collect PDM data.
       */
      port_t p_pdm_mics;

      /**
       * Number of words left to capture for the current block.
       */
      unsigned phase;

      /**
       * @brief PDM block redirection pointers.
       *
       * Each time a new block of data is ready, a double buffer pointer swap
       * is performed and `blocks[1]` is passed to `SubType::SendBlock()` so
       * that it can be signaled to the next processing stage.
       */
      uint32_t* blocks[2];
      volatile bool shutdown = false;
      volatile bool shutdown_complete = false;
      uint32_t pdm_out_words_per_channel; // number of 32-sample subblocks per channel
      uint32_t num_phases;

      /**
       * @brief Streaming channel over which PDM blocks are sent.
       */
      streaming_channel_t c_pdm_blocks;

      /**
       * @brief Maps input channel indices to output channel indices.
       *
       * The output channel with index `k` will be derived from the input channel with index `channel_map[k]`.
       *
       * By default, the mapping will be direct (i.e. `channel_map[k] = k`).
       *
       * Set with the `MapChannel()` or `MapChannels()` methods.
       */
      unsigned channel_map[CHANNELS_OUT];

      uint32_t *pdm_out_block_ptr;

      volatile bool isr_used = false;

    public:

      /**
       * @brief Read a word of PDM data from the port.
       *
       * @return A `uint32_t` containing 32 PDM samples. If `MIC_COUNT >= 2` the
       *         samples from each port will be interleaved together.
       */
      uint32_t ReadPort();

      /**
       * @brief Send a block of PDM data to a listener.
       *
       * @param block   PDM data to send.
       */
      void SendBlock(uint32_t *block);

      /**
       * @brief Initialize the PDM RX service.
       *
       * Sets the input port and binds application-provided buffers from @ref pdm_rx_conf_t @p pdm_rx_config.
       *
       * Requirements:
       * - @p pdm_rx_config.pdm_in_double_buf must be sized
       *   2 * CHANNELS_IN * @p pdm_rx_config.pdm_out_words_per_channel words and remain valid
       *   for the lifetime of the service.
       * - @p pdm_rx_config.pdm_out_block must be sized
       *   CHANNELS_OUT * @p pdm_rx_config.pdm_out_words_per_channel words and remain valid
       *   for the lifetime of the service.
       *
       * @param p_pdm_mics     Port from which PDM samples are captured.
       * @param pdm_rx_config  PDM RX configuration
       */
      void Init(port_t p_pdm_mics, pdm_rx_conf_t &pdm_rx_config);

      /**
       * @brief Set the input-output mapping for all output channels.
       *
       * By default, input channel index `k` maps to output channel index `k`.
       *
       * This method overrides that behavior for all channels, re-mapping each
       * output channel such that output channel `k` is derived from input
       * channel `map[k]`.
       *
       * @note Changing the channel mapping while the mic array unit is running
       *       is not recommended.
       *
       * @param map Array containing new channel map.
       */
      void MapChannels(const unsigned map[CHANNELS_OUT]);

      /**
       * @brief Set the input-output mapping for a single output channel.
       *
       * By default, input channel index `k` maps to output channel index `k`.
       *
       * This method overrides that behavior for a single output channel,
       * configuring output channel `out_channel` to be derived from input
       * channel `in_channel`.
       *
       * @note Changing the channel mapping while the mic array unit is running
       *       is not recommended.
       *
       * @param out_channel   Output channel index to be re-mapped.
       * @param in_channel    New source channel index for `out_channel`.
       */
      void MapChannel(unsigned out_channel, unsigned in_channel);

      /**
       * @brief Install ISR for PDM reception on the current core.
       *
       * @note This does not unmask interrupts.
       */
      void InstallISR();

      /**
       * @brief Unmask interrupts on the current core.
       */
      void UnmaskISR();

      /**
       * @brief Get a block of PDM data.
       *
       * Because blocks of PDM samples are delivered by pointer, the caller must
       * either copy the samples or finish processing them before the next block
       * of samples is ready, or the data will be clobbered.
       *
       * @note This is a blocking call.
       *
       * @returns Pointer to block of PDM data.
       */
      uint32_t* GetPdmBlock();

      /**
       * @brief Set whether dropped PDM samples should cause an assertion.
       *
       * If `doAssert` is set to `true` (default), the PDM rx ISR will raise an
       * exception (`ET_CALL`) if it is ready to deliver a PDM block to the mic
       * array thread when the mic array thread is not ready to receive it. If
       * `false`, dropped blocks can be tracked through
       * `pdm_rx_isr_context.missed_blocks`.
       */
      void AssertOnDroppedBlock(bool doAssert);

      void Shutdown();
      /**
       * @brief Set the port from which to collect PDM samples.
       */
      void SetPort(port_t p_pdm_mics);

      /**
       * @brief Entry point for PDM processing thread.
       *
       * This function loops forever, performing a port read and if a new block has completed, signal a block send,
       * every iteration.
       */
      void ThreadEntry();
  };

}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////


//////////////////////////////////////////////
//          StandardPdmRxService            //
//////////////////////////////////////////////

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>::SetPort(port_t p_pdm_mics)
{
  this->p_pdm_mics = p_pdm_mics;
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>::ThreadEntry()
{
  while(1){
    this->blocks[0][--phase] =  this->ReadPort();

    if(!phase){
      this->phase = this->num_phases;
      uint32_t* ready_block = this->blocks[0];
      this->blocks[0] = this->blocks[1];
      this->blocks[1] = ready_block;

      this->SendBlock(ready_block);
      // Check for shutdown only after sending a block so we know there's atleast one pending block at the time of shutdown
      if(this->shutdown)
      {
        break;
      }
    }
  }
  this->shutdown_complete = true;
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
uint32_t mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::ReadPort()
{
  return port_in(this->p_pdm_mics);
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::SendBlock(uint32_t *block)
{
  s_chan_out_word(this->c_pdm_blocks.end_a,
                  reinterpret_cast<uint32_t>( &block[0] ));
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::Init(port_t p_pdm_mics, pdm_rx_conf_t &pdm_rx_config)
{
  this->pdm_out_block_ptr = pdm_rx_config.pdm_out_block;
  this->pdm_out_words_per_channel = pdm_rx_config.pdm_out_words_per_channel;
  this->num_phases = CHANNELS_IN * this->pdm_out_words_per_channel;
  this->phase = this->num_phases;


  this->blocks[0] = pdm_rx_config.pdm_in_double_buf;
  this->blocks[1] = pdm_rx_config.pdm_in_double_buf + this->num_phases;

  for(int k = 0; k < CHANNELS_OUT; k++)
    this->channel_map[k] = k;

  this->c_pdm_blocks = s_chan_alloc();

  this->SetPort(p_pdm_mics);
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::MapChannels(const unsigned map[CHANNELS_OUT])
{
  for(int k = 0; k < CHANNELS_OUT; k++)
    this->channel_map[k] = map[k];
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::MapChannel(unsigned out_channel, unsigned in_channel)
{
  this->channel_map[out_channel] = in_channel;
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::InstallISR()
{
  this->isr_used = true;
  pdm_rx_isr_context.p_pdm_mics = this->p_pdm_mics;
  pdm_rx_isr_context.c_pdm_data = this->c_pdm_blocks.end_a;
  pdm_rx_isr_context.pdm_buffer[0] = this->blocks[0];
  pdm_rx_isr_context.pdm_buffer[1] = this->blocks[1];
  pdm_rx_isr_context.phase_reset = this->num_phases - 1;
  pdm_rx_isr_context.phase = this->num_phases - 1;

  enable_pdm_rx_isr(this->p_pdm_mics);
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::AssertOnDroppedBlock(bool doAssert)
{
  pdm_rx_isr_context.missed_blocks = doAssert? -1 : 0;
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::UnmaskISR()
{
  interrupt_unmask_all();
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
uint32_t* mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::GetPdmBlock()
{
  // Has to be in a critical section to avoid race conditions with ISR.
  interrupt_mask_all();
  // Limiting credit to 1 prevents the ISR from attempting to enqueue an additional block
  // while two buffers are already occupied (which would happen if the ISR gets triggered between interrupt_unmask_all()
  // and s_chan_in_word()), thereby avoiding deadlock.
  pdm_rx_isr_context.credit = 1;
  interrupt_unmask_all();


  uint32_t* full_block = (uint32_t*) s_chan_in_word(this->c_pdm_blocks.end_b);
  mic_array::deinterleave_pdm_samples<CHANNELS_IN>(full_block, this->pdm_out_words_per_channel);

  uint32_t (*block)[CHANNELS_IN] = (uint32_t (*)[CHANNELS_IN]) full_block;
  uint32_t *out_ptr;
  for(int ch = 0; ch < CHANNELS_OUT; ch++) {
    out_ptr = this->pdm_out_block_ptr + (ch * this->pdm_out_words_per_channel);
    for(int sb = 0; sb < this->pdm_out_words_per_channel; sb++) {
      unsigned d = this->channel_map[ch];
      out_ptr[sb] = block[this->pdm_out_words_per_channel - 1 - sb][d];
    }
  }
  return this->pdm_out_block_ptr;
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT>
    ::Shutdown() {
  if(this->isr_used) {
    interrupt_mask_all(); // With the way the credit scheme is,
                          //there isn't going to be a pending block unless credit is set in GetPdmBlock(), so mask interrupts and return
  }
  else
  {
    this->shutdown = true; // start the shutdown process of the PdmRx thread
    // The way PdmRx thread shutdown works, there will be atleast one pending block. Read it.
    uint32_t *pdm_samples = GetPdmBlock(); // It's important to Get the Pdm block first in case PdmRx thread is blocked on SendBlock()
                                           // Getting a block unblocks it.
                                           // Also, reading a block ensures there's space in the channel buffer for another block
                                           // so SendBlock() will return and see this->shutdown as set
    // The block we just read could be a buffered block due to streaming channel
    // so we need to explicitly wait for PdmRx thread to exit since
    // we can't be draining blocks while PdmRx is still running.
    while(!this->shutdown_complete) {
      continue;
    }
    // Now that we're sure that PdmRx thread has exited, drain any pending blocks
    SELECT_RES(CASE_THEN(this->c_pdm_blocks.end_b, rx_pending_block),
                 DEFAULT_THEN(empty))
    {
      rx_pending_block:
        pdm_samples = GetPdmBlock();
        SELECT_CONTINUE_NO_RESET;

      empty:
        break;
    }
  }
  // Now that shutdown is complete, free the pdmrx channel
  s_chan_free(this->c_pdm_blocks);
}
