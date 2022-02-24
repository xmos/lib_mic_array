#pragma once

#ifdef __XC__
extern "C" {
#endif //__XC__


static inline
pdm_rx_resources_t pdm_rx_resources_sdr(
    port_t p_mclk,
    port_t p_pdm_clk,
    port_t p_pdm_mics,
    clock_t clock_a)
{
  pdm_rx_resources_t res;
  res.p_mclk = p_mclk;
  res.p_pdm_clk = p_pdm_clk;
  res.p_pdm_mics = p_pdm_mics;
  res.clock_a = clock_a;
  res.clock_b = 0;
  return res;
}


static inline
pdm_rx_resources_t pdm_rx_resources_ddr(
    port_t p_mclk,
    port_t p_pdm_clk,
    port_t p_pdm_mics,
    clock_t clock_a,
    clock_t clock_b)
{
  pdm_rx_resources_t res;
  res.p_mclk = p_mclk;
  res.p_pdm_clk = p_pdm_clk;
  res.p_pdm_mics = p_pdm_mics;
  res.clock_a = clock_a;
  res.clock_b = clock_b;
  return res;
}


static inline
unsigned pdm_rx_uses_ddr(
    pdm_rx_resources_t* pdm_res)
{ 
  return pdm_res->clock_b != 0; 
}


static inline
pdm_rx_context_t pdm_rx_context(
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


#ifdef __XC__
}
#endif //__XC__