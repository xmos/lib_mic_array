#pragma once



static inline
void mic_array_setup(
    pdm_rx_resources_t* pdm_res,
    int divide)
{
  if( pdm_rx_uses_ddr(pdm_res) )
    mic_array_setup_ddr(pdm_res, divide);
  else
    mic_array_setup_sdr(pdm_res, divide);
}

static inline
void mic_array_start(
    pdm_rx_resources_t* pdm_res)
{
  if( pdm_rx_uses_ddr(pdm_res) )
    mic_array_start_ddr(pdm_res);
  else
    mic_array_start_sdr(pdm_res);
}

static inline
unsigned mic_array_mclk_divider(
  const unsigned master_clock_freq,
  const unsigned pdm_clock_freq)
{ 
  return master_clock_freq / pdm_clock_freq; 
}

