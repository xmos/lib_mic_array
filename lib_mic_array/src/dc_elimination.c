// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "mic_array/dc_elimination.h"

#include <string.h>

void dcoe_state_init(
    dcoe_chan_state_t state[],
    const unsigned chan_count)
{
  memset(state, 0, sizeof(dcoe_chan_state_t) * chan_count);
}

void dcoe_filter(
    int32_t new_output[],
    dcoe_chan_state_t state[],
    int32_t new_input[],
    const unsigned chan_count)
{
  #define N   32
  #define Q   6

  for(int k = 0; k < chan_count; k++){
    const int64_t x_new = ((int64_t)new_input[k]) << N;
    state[k].prev_y += x_new;
    new_output[k] = state[k].prev_y >> N;
    // Doing these next two steps here avoids the need to store the 
    // inputs between samples
    state[k].prev_y = state[k].prev_y - (state[k].prev_y >> Q);
    state[k].prev_y = state[k].prev_y - x_new; 

  }

  #undef N
  #undef Q
}
