
#include "mic_array/pdm_rx.h"
#include "fir_1x16_bit.h"

#include "xs3_math.h"

#include <xcore/port.h>
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
extern struct {
  port_t p_pdm_mics;
  pdm_rx_context_t state;
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



pdm_rx_context_t pdm_rx_context_create(
    uint32_t* pdm_buffer_a,
    uint32_t* pdm_buffer_b,
    const unsigned buffer_words)
{
  pdm_rx_context_t ctx;
  ctx.pdm_buffer[0] = pdm_buffer_a;
  ctx.pdm_buffer[1] = pdm_buffer_b;
  ctx.phase_reset = buffer_words - 1;
  ctx.phase = ctx.phase_reset;
  return ctx;
}




void pdm_rx_isr_enable(
    const port_t p_pdm_mics,
    uint32_t* pdm_buffer_a,
    uint32_t* pdm_buffer_b,
    const unsigned buffer_words,
    chanend_t c_pdm_data)
{
  pdm_rx_isr_context.p_pdm_mics = p_pdm_mics;
  pdm_rx_isr_context.state = pdm_rx_context_create(pdm_buffer_a,
                                                   pdm_buffer_b,
                                                   buffer_words);
  pdm_rx_isr_context.c_pdm_data = c_pdm_data;
  enable_pdm_rx_isr(p_pdm_mics);
}





void pdm_rx_buffer_send(
    const chanend_t c_pdm_data_out,
    const uint32_t* pdm_buffer)
{
  s_chan_out_word(c_pdm_data_out, (unsigned) pdm_buffer);
}




uint32_t* pdm_rx_buffer_receive(
    const chanend_t c_pdm_data_in)
{
  return (uint32_t*) s_chan_in_word(c_pdm_data_in);
}





void pdm_rx_task(
    port_t p_pdm_mics,
    pdm_rx_context_t context,
    chanend_t c_pdm_data)
{
  while(1){
    (context.pdm_buffer[0])[context.phase] = port_in(p_pdm_mics);

    if(context.phase){
      context.phase--;
    } else {
      uint32_t* buff = context.pdm_buffer[0];
      context.phase = context.phase_reset;
      context.pdm_buffer[0] = context.pdm_buffer[1];
      context.pdm_buffer[1] = buff;
      pdm_rx_buffer_send(c_pdm_data, buff);
    }
  }
}