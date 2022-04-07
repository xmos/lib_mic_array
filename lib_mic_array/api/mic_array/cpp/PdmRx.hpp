#pragma once

#include <cstdint>
#include <string>
#include <cassert>
#include <iostream>

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

/**
 * @brief Configuration for `pdm_rx_isr`.
 * 
 * `pdm_rx_isr` (`pdm_rx_isr.S`) allocates this struct as configuration and
 * state parameters required by that interrupt routine.
 * 
 * Used by `StandardPdmRxService`.
 */
extern "C" {
  extern struct {
    port_t p_pdm_mics;
    uint32_t* pdm_buffer[2];
    unsigned phase;
    unsigned phase_reset;
    chanend_t c_pdm_data;
  } pdm_rx_isr_context;

  /**
   * @brief Configure port to use `pdm_rx_isr` as an interrupt routine.
   * 
   * This function configures `p_pdm_mics` to use `pdm_rx_isr` as its interrupt
   * vector and enables the interrupt on the current core.
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
   * @brief Used to collect PDM sample data from a port.
   * 
   * This class is used to collect blocks of PDM data from a port and send the
   * data to a decimator for further processing.
   * 
   * `PdmRxService` is a base class using CRTP. Subclasses extend `PdmRxService`
   * providing themselves as the template parameter `SubType`.
   * 
   * This base class provides the logic for aggregating PDM data taken from 
   * a port into blocks, and a subclass is required to provide methods 
   * `SubType::ReadPort()` and `SubType::SendBlock()`.
   * 
   * `SubType::ReadPort()` is responsible for reading 1 word of data from 
   * `p_pdm_mics`.
   * 
   * `SubType::SendBlock()` is provided a block of PDM data as a pointer and is
   * responsible for signaling that to the subsequent processing stage. (Called
   * from PdmRx thread or ISR)
   * 
   * `SubType::GetPdmBlock()` (called from MicArray thread) is responsible for
   * receiving a block of PDM data from `SubType::SendBlock()` as a pointer,
   * deinterleaving the buffer contents, and returning a pointer to the PDM data
   * in the format expected by the mic array unit's decimator component.
   * 
   * @tparam BLOCK_SIZE   Number of words of PDM data per block.
   * @tparam SubType      Subclass of `PdmRxService`
   */
  template <unsigned BLOCK_SIZE, class SubType>
  class PdmRxService
  {
    // @todo: Use a static assertion to check that SubType is in fact a sub-type
    //        of `PdmRxService`. 

    public:

      /**
       * @brief Number of words of PDM data per block.
       */
      static constexpr unsigned BlockSize = BLOCK_SIZE;

    protected:
      /**
       * @brief Port from which to collect PDM data.
       */
      port_t p_pdm_mics;  

      /**
       * @brief Number of words left to capture for the current block.
       */
      unsigned phase = BLOCK_SIZE;

      /**
       * @brief Buffers for PDM data blocks.
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
       * @brief Construct a `PdmRxService` object.
       * 
       * This constructor does not intialize `p_pdm_mics`. A subsequent call to
       * `SetPort()` will be required prior to any call to `ProcessNext()` or
       * `ThreadEntry()`.
       */
      PdmRxService() { }

      /**
       * @brief Construct a `PdmRxService` object.
       * 
       * This constructor initializes `p_pdm_mics`. No subsequent call to
       * `SetPort()` is necessary.
       */
      PdmRxService(port_t p_pdm_mics) : p_pdm_mics(p_pdm_mics) { }

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
   * 
   * A streaming channel is used to transfer control of the PDM data block
   * between contexts (i.e. thread->thread or ISR->thread).
   * 
   * The `MicArray` unit receives blocks of PDM data from an instance of this
   * class by calling `GetPdmBlock()`, which blocks until a new PDM block is
   * available.
   * 
   * @par Layouts
   *  
   * The buffer transferred by `SendBlock()` contains `CHANNELS_IN*`SUBBLOCKS`
   * words of PDM data for `CHANNELS_IN` microphone channels. The words are
   * stored in reverse order of arrival. See `deinterleave_pdm_samples<>()` for
   * additional details on this format.
   * 
   * Within `GetPdmBlock()` (i.e. mic array thread) the PDM data block is
   * deinterleaved and copied to another buffer in the format required by the
   * decimator component, which is returned by `GetPdmBlock()`. This buffer
   * contains samples for `CHANNELS_OUT` microphone channels.
   * 
   * @par Channel Filtering
   * 
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
   * the width (in bits) of the xCore port to which the microphones are
   * physically connected. When in a DDR configuration, `CHANNELS_IN` must be
   * twice the width (in bits) of the xCore port to which the microphones are
   * physically connected.
   *
   * `CHANNELS_OUT` is the number of microphone channels to be consumed by the
   * decimator unit (i.e. must be the same as the `MIC_COUNT` template parameter
   * of the decimator component). If all port pins are connected to microphones,
   * this parameter will generally be the same as `CHANNELS_IN`.
   * 
   * @par Channel Index (Re-)Mapping
   * 
   * The input channel index of a microphone depends on the pin to which it is
   * connected. Each pin connected to a port has a bit index for that port,
   * given in the 'Signal Description and GPIO' section of your package's
   * datasheet.
   *
   * Suppose an `N`-bit port is used to capture microphone data, and a
   * microphone is connected to bit `B` of that port.  In an SDR microphone
   * configuration, the input channel index of that microphone is `B` -- the
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
   * 
   * @tparam CHANNELS_IN  The number of microphone channels to be captured by
   * the port.
   * @tparam CHANNELS_OUT The number of microphone channels to be delivered by
   * this `StandardPdmRxService` instance.
   * @tparam SUBBLOCKS    The number of 32-sample sub-blocks to be captured for
   * each microphone channel.
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
       * @brief Construct a `StandardPdmRxService` object.
       * 
       * A subsequent call to `SetPort()` and `SetChannel()` will be required 
       * prior to any call to `ProcessNext()`, `GetPdmBlock()` or 
       * `ThreadEntry()`.
       */
      StandardPdmRxService();

      /**
       * @brief Construct a `PdmRxService` object.
       * 
       * This constructor does not intialize `p_pdm_mics`. A subsequent call to
       * `SetPort()` will be required prior to any call to `ProcessNext()` or
       * `ThreadEntry()`.
       */
      StandardPdmRxService(port_t p_pdm_mics);

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
       * @param c_pdm_blocks Streaming channel to send PDM data over.
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
mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::StandardPdmRxService() 
{
  for(int k = 0; k < CHANNELS_OUT; k++)
    this->channel_map[k] = k;
}

template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::StandardPdmRxService(port_t p_pdm_mics) : Super(p_pdm_mics)
{
  for(int k = 0; k < CHANNELS_OUT; k++)
    this->channel_map[k] = k;
}


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
  this->c_pdm_blocks = s_chan_alloc();
  assert(this->c_pdm_blocks.end_a != 0 && this->c_pdm_blocks.end_b != 0);

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
    ::UnmaskISR() 
{
  interrupt_unmask_all();
}


template <unsigned CHANNELS_IN, unsigned CHANNELS_OUT, unsigned SUBBLOCKS>
uint32_t* mic_array::StandardPdmRxService<CHANNELS_IN, CHANNELS_OUT, SUBBLOCKS>
    ::GetPdmBlock() 
{
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
