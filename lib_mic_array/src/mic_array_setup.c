// Copyright 2021-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "mic_array.h"

#include <platform.h>
#include <xs1.h>
#include <xccompat.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>


void mic_array_resources_configure(
    pdm_rx_resources_t* pdm_res,
    int divide)
{
  const unsigned is_ddr = pdm_res->clock_b != 0;

  port_reset(pdm_res->p_mclk);
  port_reset(pdm_res->p_pdm_clk);
  port_reset(pdm_res->p_pdm_mics);

  clock_enable(pdm_res->clock_a);
  port_enable(pdm_res->p_mclk);
  clock_set_source_port(pdm_res->clock_a, pdm_res->p_mclk);
  clock_set_divide(pdm_res->clock_a, divide/2);

  if(is_ddr){
    clock_enable(pdm_res->clock_b);
    clock_set_source_port(pdm_res->clock_b, pdm_res->p_mclk);
    clock_set_divide(pdm_res->clock_b, divide/4);
  }

  port_enable(pdm_res->p_pdm_clk);
  port_set_clock(pdm_res->p_pdm_clk, pdm_res->clock_a);
  port_set_out_clock(pdm_res->p_pdm_clk);

  port_start_buffered(pdm_res->p_pdm_mics, 32);
  port_set_clock(pdm_res->p_pdm_mics, is_ddr? pdm_res->clock_b
                                            : pdm_res->clock_a);
  port_clear_buffer(pdm_res->p_pdm_mics);
}


void mic_array_pdm_clock_start(
    pdm_rx_resources_t* pdm_res)
{
  if( pdm_res->clock_b != 0 ) {
    uint32_t tmp;
    
    port_clear_buffer(pdm_res->p_pdm_mics);
    
    /* start the faster capture clock */
    clock_start(pdm_res->clock_b);

    /* wait for a rising edge on the capture clock */
    // (this ensures the rising edges of the two 
    //  clocks are not in phase)
    asm volatile("inpw %0, res[%1], 8" : "=r"(tmp) 
                    : "r" (pdm_res->p_pdm_mics));

    /* start the slower output clock */
    clock_start(pdm_res->clock_a);
  } else {
    // You'd think that we could move the `clock_start(pdm_res->clock_a)` to be
    //  after the if..else block instead of duplicating it. But no, if I try 
    //  that, the compiler screws something up and the output audio is all 
    //  messed up.
    clock_start(pdm_res->clock_a);
  }
}
