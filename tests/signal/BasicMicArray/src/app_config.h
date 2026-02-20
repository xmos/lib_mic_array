// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#if defined(__VX4B__)

#include <vx_ports.h>

#ifndef PORT_MCLK_IN
#define PORT_MCLK_IN    XS1_PORT_1D 
#endif

#ifndef PORT_PDM_CLK
#define PORT_PDM_CLK    XS1_PORT_1G 
#endif

#ifndef PORT_PDM_DATA
#define PORT_PDM_DATA   XS1_PORT_1F 
#endif

#endif
