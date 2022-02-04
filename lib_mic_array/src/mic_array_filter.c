
#include "mic_array_filter.h"


void ma_stage2_filters_init(
    xs3_filter_fir_s32_t filters[],
    int32_t state_buffers[],
    const unsigned mic_count,
    const unsigned stage2_tap_count,
    const int32_t* stage2_coef,
    const right_shift_t stage2_shr)
{
  for(int k = 0; k < mic_count; k++){
    xs3_filter_fir_s32_init(&filters[k],
                            &state_buffers[k*stage2_tap_count],
                            stage2_tap_count,
                            stage2_coef,
                            stage2_shr);
  }
}