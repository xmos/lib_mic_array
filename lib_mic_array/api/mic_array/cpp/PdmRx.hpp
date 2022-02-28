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


// This is for BareMetal_PdmRxIsr only
extern "C" {

  extern struct {
    port_t p_pdm_mics;
    pdm_rx_context_t pdm_ctx;
    chanend_t c_pdm_data;
  } pdm_rx_isr_context;

  static inline void enable_pdm_rx_isr(
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

  
  template <unsigned BLOCK_SIZE, class SubType>
  class PdmRxService
  {
    public:

      static constexpr unsigned BlockSize = BLOCK_SIZE;

    protected:
      port_t p_pdm_mics;  
      unsigned phase = BLOCK_SIZE;
      uint32_t blockA[BLOCK_SIZE];
      uint32_t blockB[BLOCK_SIZE];
      uint32_t* blocks[2] = {&blockA[0], &blockB[0]};

    public:

      PdmRxService() {}
      PdmRxService(port_t p_pdm_mics) : p_pdm_mics(p_pdm_mics) { }

      void SetPort(port_t p_pdm_mics)
      {
        this->p_pdm_mics = p_pdm_mics;
      }

      void ProcessNext()
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

      void ThreadEntry()
      {
        while(1){
          this->ProcessNext();
        }
      }
      
  };



  template <unsigned BLOCK_SIZE>
  class StandardPdmRxService : public PdmRxService<BLOCK_SIZE, StandardPdmRxService<BLOCK_SIZE>>
  {
    using Super = PdmRxService<BLOCK_SIZE, StandardPdmRxService<BLOCK_SIZE>>;

    private:

      streaming_channel_t c_pdm_blocks;
   
    public:

      uint32_t ReadPort()
      {
        return port_in(this->p_pdm_mics);
      }

      void SendBlock(uint32_t block[BLOCK_SIZE])
      {
        s_chan_out_word(this->c_pdm_blocks.end_a, 
                        reinterpret_cast<uint32_t>( &block[0] ));
      }


      StandardPdmRxService() { }
      StandardPdmRxService(port_t p_pdm_mics, 
                           streaming_channel_t c_pdm_blocks)
          : Super(p_pdm_mics), c_pdm_blocks(c_pdm_blocks) { }

      void SetChannel(streaming_channel_t c_pdm_blocks) {
        this->c_pdm_blocks = c_pdm_blocks;
      }

      void Init(port_t p_pdm_mics, 
                streaming_channel_t c_pdm_blocks) {
        this->SetPort(p_pdm_mics);
        this->SetChannel(c_pdm_blocks);
      }

      void InstallISR() {
        pdm_rx_isr_context.p_pdm_mics = this->p_pdm_mics;
        pdm_rx_isr_context.c_pdm_data = this->c_pdm_blocks.end_a;
        pdm_rx_isr_context.pdm_ctx.pdm_buffer[0] = this->blockA;
        pdm_rx_isr_context.pdm_ctx.pdm_buffer[1] = this->blockB;
        pdm_rx_isr_context.pdm_ctx.phase_reset = BLOCK_SIZE-1;
        pdm_rx_isr_context.pdm_ctx.phase = BLOCK_SIZE-1;

        enable_pdm_rx_isr(this->p_pdm_mics);
      }

      void UnmaskISR() {
        interrupt_unmask_all();
      }

      uint32_t* GetPdmBlock() {
        return (uint32_t*) s_chan_in_word(this->c_pdm_blocks.end_b);
      }
  };

}