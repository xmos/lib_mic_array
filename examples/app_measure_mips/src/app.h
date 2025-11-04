// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "app_config.h"
#include "app_common.h"
#include "mic_array.h"

C_API_START

MA_C_API
void app_init();

MA_C_API
void app_start(chanend_t c_frames_out);

C_API_END
