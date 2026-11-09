// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#if defined(__VX4B__)

#include <vx_ports.h>

#ifndef PORT_MCLK_IN
#define PORT_MCLK_IN    VX_PORT_1D 
#endif

#ifndef PORT_PDM_CLK
#define PORT_PDM_CLK    VX_PORT_1G 
#endif

#ifndef PORT_PDM_DATA
#define PORT_PDM_DATA   VX_PORT_1F 
#endif


#endif

#if defined(__riscv_xxcore)
#include <vx4b_defines.h>
#define MIC_ARRAY_CONFIG_CLOCK_BLOCK_A VX_CLKBLK_1
#else
#define MIC_ARRAY_CONFIG_CLOCK_BLOCK_A XS1_CLKBLK_1
#endif
