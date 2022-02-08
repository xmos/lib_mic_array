#pragma once

#include "xs3_math.h"

#include <stdint.h>

#ifdef __XC__
extern "C" {
#endif


void ma_stage2_filters_init(
    xs3_filter_fir_s32_t filters[],
    int32_t state_buffers[],
    const unsigned mic_count,
    const unsigned stage2_tap_count,
    const int32_t* stage2_coef,
    const right_shift_t stage2_shr);



#ifdef __XC__
}
#endif //__XC__