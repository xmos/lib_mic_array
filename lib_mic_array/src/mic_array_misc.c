
#include "mic_array_misc.h"

#include <string.h>



void ma_dc_elimination_init(
    ma_dc_elim_chan_state_t state[],
    const unsigned chan_count)
{
  memset(state, 0, sizeof(ma_dc_elim_chan_state_t) * chan_count);
}

void ma_dc_elimination_next_sample(
    int32_t new_output[],
    ma_dc_elim_chan_state_t state[],
    int32_t new_input[],
    const unsigned chan_count)
{
  #define N   32
  #define Q   8

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