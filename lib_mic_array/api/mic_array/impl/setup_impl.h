// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

// Doxygen gets confused when it sees this.
#ifndef __DOXYGEN__

static inline
unsigned mic_array_mclk_divider(
  const unsigned master_clock_freq,
  const unsigned pdm_clock_freq)
{ 
  return master_clock_freq / pdm_clock_freq; 
}

#endif