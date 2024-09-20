// Copyright 2021-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <stdint.h>

#include "mic_array/api.h"

C_API_START;

extern uint64_t tick_count;
extern uint64_t inst_count;

MA_C_API
void burn_mips();

MA_C_API
void count_mips();

MA_C_API
void print_mips(const unsigned use_pdm_rx_isr);


C_API_END