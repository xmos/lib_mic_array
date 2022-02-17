
#include "mic_array.h"

#include <platform.h>
#include <xs1.h>
#include <xccompat.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>





void mic_array_setup_sdr(
    pdm_rx_resources_t* pdm_res,
    int divide)
{
    clock_enable(pdm_res->clock_a);
    port_enable(pdm_res->p_mclk);
    clock_set_source_port(pdm_res->clock_a, pdm_res->p_mclk);
    clock_set_divide(pdm_res->clock_a, divide/2);

    port_enable(pdm_res->p_pdm_clk);
    port_set_clock(pdm_res->p_pdm_clk, pdm_res->clock_a);
    port_set_out_clock(pdm_res->p_pdm_clk);

    port_start_buffered(pdm_res->p_pdm_mics, 32);
    port_set_clock(pdm_res->p_pdm_mics, pdm_res->clock_a);
    port_clear_buffer(pdm_res->p_pdm_mics);
}



void mic_array_start_sdr(
    pdm_rx_resources_t* pdm_res)
{
  clock_start(pdm_res->clock_a);
}



void mic_array_setup_ddr(
    pdm_rx_resources_t* pdm_res,
    int divide)
{

  clock_enable(pdm_res->clock_a);
  port_enable(pdm_res->p_mclk);
  clock_set_source_port(pdm_res->clock_a, pdm_res->p_mclk);
  clock_set_divide(pdm_res->clock_a, divide/2);

  clock_enable(pdm_res->clock_b);
  clock_set_source_port(pdm_res->clock_b, pdm_res->p_mclk);
  clock_set_divide(pdm_res->clock_b, divide/4);

  port_enable(pdm_res->p_pdm_clk);
  port_set_clock(pdm_res->p_pdm_clk, pdm_res->clock_a);
  port_set_out_clock(pdm_res->p_pdm_clk);

  port_start_buffered(pdm_res->p_pdm_mics, 32);
  port_set_clock(pdm_res->p_pdm_mics, pdm_res->clock_b);
}



void mic_array_start_ddr(
    pdm_rx_resources_t* pdm_res)
{
  uint32_t tmp;
  
  port_clear_buffer(pdm_res->p_pdm_mics);
  
  /* start the faster capture clock */
  clock_start(pdm_res->clock_b);

  /* wait for a rising edge on the capture clock */
  // (this ensures the rising edges of the two clocks are not in phase)
  asm volatile("inpw %0, res[%1], 4" : "=r"(tmp) : "r" (pdm_res->p_pdm_mics));

  /* start the slower output clock */
  clock_start(pdm_res->clock_a);
}


