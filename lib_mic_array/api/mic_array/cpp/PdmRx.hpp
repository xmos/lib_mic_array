// Copyright 2022-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <cstdint>
#include <string>
#include <cassert>

#include <xcore/interrupt.h>
#include <xcore/channel_streaming.h>
#include <xcore/port.h>

#include "mic_array.h"
#include "Util.hpp"

// This has caused problems previously, so just catch the problems here.
#if defined(BLOCK_SIZE) || defined(CHANNELS_IN) || defined(CHANNELS_OUT) || defined(SUBBLOCKS)
# error Application must not define the following as precompiler macros: MIC_COUNT, CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS.
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
     * The buffers themselves are allocated by an instance of @ref
     * mic_array::PdmRxService. The idea is that while the PDM rx ISR is filling
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
    asm volatile(
      "setc res[%0], %1       \n"
      "ldap r11, pdm_rx_isr   \n"
      "setv res[%0], r11      \n"
      "eeu res[%0]              "
        :
        : "r"(p_pdm_mics), "r"(XS1_SETC_IE_MODE_INTERRUPT)
        : "r11" );
  }

}


namespace  mic_array {



  /**
   * @brief Collects PDM sample data from a port.
   * 
   * Derivatives of this class template are intended to be used for the `TPdmRx`
   * template parameter of @ref MicArray, where it represents the @ref
   * MicArray::PdmRx component of the mic array.
   * 
   * An object derived from `PdmRxService` collects blocks of PDM samples from a
   * port and makes them available to the decimation thread as the blocks are 
   * completed.
   * 
   * `PdmRxService` is a base class using CRTP. Subclasses extend `PdmRxService`
   * providing themselves as the template parameter `SubType`.
   * 
   * This base class provides the logic for aggregating PDM data taken from 
   * a port into blocks, and a subclass is required to provide methods 
   * `SubType::ReadPort()`, `SubType::SendBlock()` and `SubType::GetPdmBlock()`.
   * 
   * `SubType::ReadPort()` is responsible for reading 1 word of data from 
   * `p_pdm_mics`. See @ref StandardPdmRxService::ReadPort() as an example.
   * 
   * `SubType::SendBlock()` is provided a block of PDM data as a pointer and is
   * responsible for signaling that to the subsequent processing stage. See
   * @ref StandardPdmRxService::SendBlock() as an example.
   * 
   * `ReadPort()` and `SendBlock()` are used by `PdmRxService` itself (when
   * running as a thread, rather than ISR).
   * 
   * `SubType::GetPdmBlock()` responsible for receiving a block of PDM data from
   * `SubType::SendBlock()` as a pointer, deinterleaving the buffer contents,
   * and returning a pointer to the PDM data in the format expected by the mic
   * array unit's decimator component. See 
   * @ref StandardPdmRxService::GetPdmBlock() as an example.
   * 
   * `GetPdmBlock()` is called by the decimation thread. The pair of functions,
   * `SendBlock()` and `GetPdmBlock()` facilitate inter-thread communication,
   * `SendBlock()` being called by the transmitting end of the communication 
   * channel, and `GetPdmBlock()` being called by the receiving end.
   * 
   * @tparam BLOCK_SIZE   Number of words of PDM data per block.
   * @tparam SubType      Subclass of `PdmRxService` actually being used.
   */
  template <unsigned BLOCK_SIZE, class SubType>
  class PdmRxService
  {
    // @todo: Use a static assertion to check that SubType is in fact a sub-type
    //        of `PdmRxService`. 

    public:

      /**
       * @brief Number of words of PDM data per block.
       * 
       * Typically (e.g. @ref TwoStageDecimator) `BLOCK_SIZE` will be exactly
       * the number of words of PDM samples required to produce exactly one new
       * output sample for the mic array unit's output stream.
       * 
       * Once `BlockSize` words have been read into one of the @ref block_data, 
       * buffers, PDM rx will signal to the decimator thread that new PDM data
       * is available for processing.
       */
      static constexpr unsigned BlockSize = BLOCK_SIZE;

    protected:
      /**
       * @brief Port from which to collect PDM data.
       */
      port_t p_pdm_mics;  

      /**
       * Number of words left to capture for the current block.
       */
      unsigned phase = BLOCK_SIZE;

      /**
       * @brief Buffers for PDM data blocks.
       * 
       * The PDM rx service will swap back and forth between filling these two
       * buffers.
       */
      uint32_t block_data[2][BLOCK_SIZE];

      /**
       * @brief PDM block redirection pointers.
       * 
       * Each time a new block of data is ready, a double buffer pointer swap
       * is performed and `blocks[1]` is passed to `SubType::SendBlock()` so 
       * that it can be signaled to the next processing stage.
       */
      uint32_t* blocks[2] = {&block_data[0][0], &block_data[1][0]};

    public:

      /**
       * @brief Set the port from which to collect PDM samples.
       */
      void SetPort(port_t p_pdm_mics);

      /**
       * @brief Perform a port read and if a new block has completed, signal.
       */
      void ProcessNext();

      /**
       * @brief Entry point for PDM processing thread.
       * 
       * This function loops forever, calling `ProcessNext()` with each 
       * iteration.
       */
      void ThreadEntry();
      
  };


  /**
   * @brief PDM rx service which uses a streaming channel to send a block of
   *        data by pointer.
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
   * @par Layouts
   * @parblock
   * The buffer transferred by `SendBlock()` contains `CHANNELS_IN*SUBBLOCKS`
   * words of PDM data for `CHANNELS_IN` microphone channels. The words are
   * stored in reverse order of arrival. \verbatim embed:rst
     See :cpp:func:`mic_array::deinterleave_pdm_samples` for additional details 
     on this format.\endverbatim
   * 
   * Within `GetPdmBlock()` (i.e. mic array thread) the PDM data block is
   * deinterleaved and copied to another buffer in the format required by the
   * decimator component, which is returned by `GetPdmBlock()`. This buffer
   * contains samples for `CHANNELS_OUT` microphone channels.
   * @endparblock
   * 
   * @par Channel Filtering
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
   * @tparam CHANNELS_IN  The number of microphone channels to be captured by
   *                      the port.
   * @tparam CHANNELS_OUT The number of microphone channels to be delivered by
   *                      this `StandardPdmRxService` instance.
   * @tparam SUBBLOCKS    The number of 32-sample sub-blocks to be captured for
   *                      each microphone channel.
   */
  template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
  class StandardPdmRxService : public PdmRxService<CHANNELS_IN * SUBBLOCKS, 
                                      StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>>
  {
    /**
     * @brief Alias for parent class.
     */
    using Super = PdmRxService<CHANNELS_IN * SUBBLOCKS, 
                    StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>>;

    private:
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

      /**
       * @brief Buffer for output PDM data.
       * 
       * A pointer to this array is delivered to the Decimator component for
       * decimation. `GetPdmBlock()` (called from the mic array thread)
       * populates this array (based on `channel_map`) after deinterleaving the
       * PDM input buffer.
       */
      uint32_t out_block[CHANNELS_OUT][SUBBLOCKS];
   
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
      void SendBlock(uint32_t block[CHANNELS_IN * SUBBLOCKS]);

      /**
       * @brief Initialize this object with a channel and port.
       * 
       * @param p_pdm_mics Port to receive PDM data on.
       */
      void Init(port_t p_pdm_mics);

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
      void MapChannels(unsigned map[CHANNELS_OUT]);

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
  };

}

//////////////////////////////////////////////
// Template function implementations below. //
//////////////////////////////////////////////


//////////////////////////////////////////////
//              PdmRxService                //
//////////////////////////////////////////////

template <unsigned BLOCK_SIZE, class SubType>
void mic_array::PdmRxService<BLOCK_SIZE,SubType>::SetPort(port_t p_pdm_mics)
{
  this->p_pdm_mics = p_pdm_mics;
}


template <unsigned BLOCK_SIZE, class SubType>
void mic_array::PdmRxService<BLOCK_SIZE,SubType>::ProcessNext()
{
  this->blocks[0][--phase] =  static_cast<SubType*>(this)->ReadPort();

  if(!phase){
    this->phase = BLOCK_SIZE;
    uint32_t* ready_block = this->blocks[0];
    this->blocks[0] = this->blocks[1];
    this->blocks[1] = ready_block;

    static_cast<SubType*>(this)->SendBlock(ready_block);
  }
}


template <unsigned BLOCK_SIZE, class SubType>
void mic_array::PdmRxService<BLOCK_SIZE,SubType>::ThreadEntry()
{
  while(1){
    this->ProcessNext();
  }
}



//////////////////////////////////////////////
//          StandardPdmRxService            //
//////////////////////////////////////////////


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
uint32_t mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::ReadPort()
{
  return port_in(this->p_pdm_mics);
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::SendBlock(uint32_t block[CHANNELS_IN*SUBBLOCKS])
{
  s_chan_out_word(this->c_pdm_blocks.end_a, 
                  reinterpret_cast<uint32_t>( &block[0] ));
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::Init(port_t p_pdm_mics) 
{
  for(int k = 0; k < CHANNELS_OUT; k++)
    this->channel_map[k] = k;

  this->c_pdm_blocks = s_chan_alloc();

  this->SetPort(p_pdm_mics);
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::MapChannels(unsigned map[CHANNELS_OUT]) 
{
  for(int k = 0; k < CHANNELS_OUT; k++)
    this->channel_map[k] = map[k];
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::MapChannel(unsigned out_channel, unsigned in_channel) 
{
  this->channel_map[out_channel] = in_channel;
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::InstallISR() 
{
  pdm_rx_isr_context.p_pdm_mics = this->p_pdm_mics;
  pdm_rx_isr_context.c_pdm_data = this->c_pdm_blocks.end_a;
  pdm_rx_isr_context.pdm_buffer[0] = &this->block_data[0][0];
  pdm_rx_isr_context.pdm_buffer[1] = &this->block_data[1][0];
  pdm_rx_isr_context.phase_reset = CHANNELS_IN*SUBBLOCKS-1;
  pdm_rx_isr_context.phase = CHANNELS_IN*SUBBLOCKS-1;

  enable_pdm_rx_isr(this->p_pdm_mics);
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::AssertOnDroppedBlock(bool doAssert)
{
  pdm_rx_isr_context.missed_blocks = doAssert? -1 : 0;
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
void mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::UnmaskISR() 
{
  interrupt_unmask_all();
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
uint32_t* mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::GetPdmBlock() 
{
  // Has to be in a critical section to avoid race conditions with ISR.
  interrupt_mask_all();
  pdm_rx_isr_context.credit = 2;
  interrupt_unmask_all();


  uint32_t* full_block = (uint32_t*) s_chan_in_word(this->c_pdm_blocks.end_b);
  mic_array::deinterleave_pdm_samples<CHANNELS_IN>(full_block, SUBBLOCKS);

  uint32_t (*block)[CHANNELS_IN] = (uint32_t (*)[CHANNELS_IN]) full_block;

  for(int ch = 0; ch < CHANNELS_OUT; ch++) {
    for(int sb = 0; sb < SUBBLOCKS; sb++) {
      unsigned d = this->channel_map[ch];
      this->out_block[ch][sb] = block[SUBBLOCKS-1-sb][d];
    } 
  }
  return &this->out_block[0][0];
}
