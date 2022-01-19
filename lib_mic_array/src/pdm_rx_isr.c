
#include "pdm_rx.h"
#include "mic_array.h"

#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <xcore/interrupt.h>


unsigned pdm_sample_count = 0;


void mic_array_pdm_rx_isr_init(
    ma_pdm_rx_context_t* context,
    const unsigned mic_count,
    const port_t p_pdm_mics,
    const uint32_t* stage1_fir_coef,
    const unsigned stage2_decimation_factor,
    uint32_t* pdm_buffer,
    int32_t* pcm_buffer)
{
  context->workspace.config.stage1.mic_count = mic_count;
  context->workspace.config.stage1.p_pdm_mics = p_pdm_mics;
  context->workspace.config.stage1.fir_coef = (int16_t*) stage1_fir_coef;
  context->workspace.config.stage1.pdm_buffer = pdm_buffer;
  context->workspace.config.stage2.decimation_factor = stage2_decimation_factor;
  context->workspace.config.stage2.pcm_vector = pcm_buffer;

  context->workspace.state.phase1 = mic_count-1;
  context->workspace.state.phase2 = 0;


  assert( (((unsigned) &context->workspace) % 4) == 0 );

  // First, set up the kernel stack on this core

  asm volatile(
    "ldaw r11, sp[0]        \n"
    "set sp, %0             \n"
    "stw r11, sp[0]         \n"
    "krestsp 0              \n"
    "setc res[%1], %2       \n"
    "ldap r11, pdm_rx_isr   \n"
    "setv res[%1], r11      \n"
    "eeu res[%1]              "
      :
      : "r"(&context->workspace), "r"(p_pdm_mics), "r"(XS1_SETC_IE_MODE_INTERRUPT)
      : "memory", "r11" );

  interrupt_unmask_all();

}
