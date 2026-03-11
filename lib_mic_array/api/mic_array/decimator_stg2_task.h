// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#include <stdint.h>
#include "xmath/xmath.h"

C_API_START

MA_C_API
void decimator_stg2_task(chanend_t c_decimator, filter_fir_s32_t *filters, const unsigned decimation_factor);

C_API_END