// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#define APP_MCLK_FREQUENCY               24576000
#define APP_PDM_CLOCK_FREQUENCY          3072000

#if defined(__VX4B__)
#include <vx_ports.h>
#define PORT_MCLK_IN    VX_PORT_1D 
#define PORT_PDM_CLK    VX_PORT_1G 
#define PORT_PDM_DATA   VX_PORT_1F 
#endif // defined(__VX4B__)
