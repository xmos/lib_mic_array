#pragma once

static inline
unsigned mic_array_mclk_divider(
  const unsigned master_clock_freq,
  const unsigned pdm_clock_freq)
{ 
  return master_clock_freq / pdm_clock_freq; 
}