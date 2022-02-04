
#include "pdm_rx.h"
#include "mic_array.h"
#include "fir_1x16_bit.h"

#include "xs3_math.h"

#include <xcore/port.h>
// #include <xcore/channel.h>
#include <xcore/channel_streaming.h>
#include <xcore/hwtimer.h>
#include <xcore/interrupt.h>

#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>




/*
  This struct is allocated directly in pdm_rx_isr.S
*/
extern pdm_rx_isr_context_t pdm_rx_context;

  

chanend_t ma_pdm_rx_isr_init(
  const port_t p_pdm_data,
  uint32_t* pdm_buffer_a,
  uint32_t* pdm_buffer_b,
  const unsigned buffer_words)
{
  pdm_rx_context.p_pdm_data = p_pdm_data;
  pdm_rx_context.pdm_buffer[0] = pdm_buffer_a;
  pdm_rx_context.pdm_buffer[1] = pdm_buffer_b;
  
  pdm_rx_context.phase_reset = buffer_words - 1;
  pdm_rx_context.phase = pdm_rx_context.phase_reset;

  pdm_rx_context.c_pdm_data = s_chan_alloc();
  assert(pdm_rx_context.c_pdm_data.end_a != 0 && pdm_rx_context.c_pdm_data.end_b != 0);

  return pdm_rx_context.c_pdm_data.end_b;
}


void ma_pdm_rx_isr_enable(
  const port_t p_pdm_data)
{
    asm volatile(
      "setc res[%0], %1       \n"
      "ldap r11, pdm_rx_isr   \n"
      "setv res[%0], r11      \n"
      "eeu res[%0]              "
        :
        : "r"(p_pdm_data), "r"(XS1_SETC_IE_MODE_INTERRUPT)
        : "r11" );
}


