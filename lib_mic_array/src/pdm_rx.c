
#include "pdm_rx.h"
#include "mic_array.h"

#include <stdint.h>
#include <assert.h>
#include <stdio.h>

#define N_MICS                   (2)
#define STAGE2_DECIMATION_FACTOR (6)

unsigned pcm_sample_count = 0;
unsigned pdm_sample_count = 0;


void proc_pcm(int32_t pcm_samples[N_MICS][STAGE2_DECIMATION_FACTOR])
{
  pcm_sample_count++;
}


void mic_array_pdm_rx_isr_init(
    ma_pdm_rx_context_t* context,
    const unsigned mic_count,
    const port_t p_pdm_mics,
    const int16_t* stage1_fir_coef,
    const unsigned stage1_fir_coef_blocks,
    const unsigned stage2_decimation_factor,
    ma_pdm_buffer_t* pdm_buffer,
    int32_t* pcm_buffer)
{
  context->workspace.config.stage1.mic_count = mic_count;
  context->workspace.config.stage1.p_pdm_mics = p_pdm_mics;
  context->workspace.config.stage1.fir_coef = (int16_t*) stage1_fir_coef;
  context->workspace.config.stage1.pdm_coef_blocks = stage1_fir_coef_blocks;
  context->workspace.config.stage1.pdm_buffer = pdm_buffer;
  context->workspace.config.stage2.decimation_factor = stage2_decimation_factor;
  context->workspace.config.stage2.pcm_vector = pcm_buffer;

  context->workspace.state.phase1 = mic_count-1;
  context->workspace.state.phase2 = 0;

  // First, set up the kernel stack on this core
  uint32_t tmp;
  asm volatile("ldaw %0, sp[0]" : "=r"(tmp) );
  asm volatile("set sp, %0" :: "r"(&context->workspace) );
  asm volatile("stw %0, sp[0]" :: "r"(tmp) : "memory" );
  asm volatile("krestsp 0");


  // Now enable the ISR for port reads.

  asm volatile("setc res[%0], %1" :: "r"(p_pdm_mics), "r"(XS1_SETC_IE_MODE_INTERRUPT) );

  #if 0 // probably not worth it?
  if( mic_count == 1 ){
    asm volatile("ldap r11, pdm_rx_isr_1mic\n"
                "setv res[%0], r11" :: "r"(p_pdm_mics) : "r11");
  } else {
    asm volatile("ldap r11, pdm_rx_isr\n"
                "setv res[%0], r11" :: "r"(p_pdm_mics) : "r11");
  }
  #endif
  
  asm volatile("ldap r11, pdm_rx_isr\n"
              "setv res[%0], r11" :: "r"(p_pdm_mics) : "r11");

  asm volatile("eeu res[%0]" :: "r"(p_pdm_mics));
  asm volatile("setsr" _XCORE_STRINGIFY(XS1_SR_IEBLE_MASK));

}