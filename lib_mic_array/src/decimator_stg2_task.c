// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <stdint.h>

#include "xmath/xmath.h"
#include "xcore/chanend.h"
#include "xcore/select.h"

void decimator_stg2_task(chanend_t c_decimator, filter_fir_s32_t *filters, const unsigned decimation_factor)
{
    chanend_out_word(c_decimator, 0);
     SELECT_RES(
        CASE_THEN(c_decimator, event_new_sample)
    )
    {
        event_new_sample:
        {
            unsigned shutdown = chanend_test_control_token_next_byte(c_decimator);
            if(shutdown) {
                break;
            }
            int32_t sample0 = chanend_in_word(c_decimator);
            filter_fir_s32_add_sample(&filters[0], sample0);
            int32_t sample1 = chanend_in_word(c_decimator);
            int32_t sample_out = filter_fir_s32(&filters[0], sample1);
            chanend_out_word(c_decimator, sample_out);
            continue;
        }
    }
}
