#pragma once

#include <cstdint>
#include <string>
#include <cassert>
#include <iostream>

#include <xcore/interrupt.h>
#include <xcore/channel_streaming.h>
#include <xcore/port.h>

#include "mic_array.h"

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
   * responsible for signaling that to the subsequent processing stage.
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
   * Completed blocks of data are transmitted by pointer over a streaming 
   * channel.
   * 
   * A decimator wishing to receive blocks of PDM data from an instance of this
   * class should call `GetPdmBlock()`, which blocks until a new PDM block is 
   * available.
   */
  template <unsigned BLOCK_SIZE>
  class StandardPdmRxService : public PdmRxService<BLOCK_SIZE, 
                                      StandardPdmRxService<BLOCK_SIZE>>
  {
    /**
     * @brief Alias for parent class.
     */
    using Super = PdmRxService<BLOCK_SIZE, StandardPdmRxService<BLOCK_SIZE>>;

    private:
      /**
       * @brief Streaming channel over which PDM blocks are sent.
       */
      streaming_channel_t c_pdm_blocks;
   
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
      void SendBlock(uint32_t block[BLOCK_SIZE]);

      /**
       * @brief Initialize this object with a channel and port.
       * 
       * @param p_pdm_mics Port to receive PDM data on.
       * @param c_pdm_blocks Streaming channel to send PDM data over.
       */
      void Init(port_t p_pdm_mics);

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



template <unsigned BLOCK_SIZE, class SubType>
void mic_array::PdmRxService<BLOCK_SIZE,SubType>::SetPort(port_t p_pdm_mics)
{
  this->p_pdm_mics = p_pdm_mics;
}


template <unsigned BLOCK_SIZE, class SubType>
void mic_array::PdmRxService<BLOCK_SIZE,SubType>::ProcessNext()
{
  blocks[0][--phase] =  static_cast<SubType*>(this)->ReadPort();

  if(!phase){
    this->phase = BLOCK_SIZE;
    uint32_t* ready_block = blocks[0];
    this->blocks[0] = blocks[1];
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




template <unsigned BLOCK_SIZE>
mic_array::StandardPdmRxService<BLOCK_SIZE>::StandardPdmRxService() 
{
}

template <unsigned BLOCK_SIZE>
mic_array::StandardPdmRxService<BLOCK_SIZE>::StandardPdmRxService(
    port_t p_pdm_mics) : Super(p_pdm_mics)
{
}


template <unsigned BLOCK_SIZE>
uint32_t mic_array::StandardPdmRxService<BLOCK_SIZE>::ReadPort()
{
  return port_in(this->p_pdm_mics);
}


template <unsigned BLOCK_SIZE>
void mic_array::StandardPdmRxService<BLOCK_SIZE>::SendBlock(
          uint32_t block[BLOCK_SIZE])
{
  s_chan_out_word(this->c_pdm_blocks.end_a, 
                  reinterpret_cast<uint32_t>( &block[0] ));
}


template <unsigned BLOCK_SIZE>
void mic_array::StandardPdmRxService<BLOCK_SIZE>::Init(
    port_t p_pdm_mics) 
{
  this->c_pdm_blocks = s_chan_alloc();
  assert(this->c_pdm_blocks.end_a != 0 && this->c_pdm_blocks.end_b != 0);

  this->SetPort(p_pdm_mics);
}


template <unsigned BLOCK_SIZE>
void mic_array::StandardPdmRxService<BLOCK_SIZE>::InstallISR() 
{
  pdm_rx_isr_context.p_pdm_mics = this->p_pdm_mics;
  pdm_rx_isr_context.c_pdm_data = this->c_pdm_blocks.end_a;
  pdm_rx_isr_context.pdm_buffer[0] = &this->block_data[0][0];
  pdm_rx_isr_context.pdm_buffer[1] = &this->block_data[1][0];
  pdm_rx_isr_context.phase_reset = BLOCK_SIZE-1;
  pdm_rx_isr_context.phase = BLOCK_SIZE-1;

  enable_pdm_rx_isr(this->p_pdm_mics);
}


template <unsigned BLOCK_SIZE>
void mic_array::StandardPdmRxService<BLOCK_SIZE>::UnmaskISR() 
{
  interrupt_unmask_all();
}


template <unsigned BLOCK_SIZE>
uint32_t* mic_array::StandardPdmRxService<BLOCK_SIZE>::GetPdmBlock() 
{
  return (uint32_t*) s_chan_in_word(this->c_pdm_blocks.end_b);
}
