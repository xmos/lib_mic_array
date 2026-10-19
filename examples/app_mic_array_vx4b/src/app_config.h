// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <vx_ports.h>

// -------------------- Frecuency and Port definitions --------------------
#define MIC_ARRAY_CONFIG_MCLK_FREQ  (24576000)        /* 24 MHz */
#define MIC_ARRAY_CONFIG_PDM_FREQ   (768000)         /* 768 KHz */
#define MIC_ARRAY_CONFIG_PORT_MCLK     VX_PORT_1P /* X0D39 */
#define MIC_ARRAY_CONFIG_PORT_PDM_CLK  VX_PORT_1L /* X0D35 */
#define MIC_ARRAY_CONFIG_PORT_PDM_DATA VX_PORT_1O /* X0D38 */
#include <vx4b_defines.h>
#define MIC_ARRAY_CONFIG_CLOCK_BLOCK_A VX_CLKBLK_2

// ------------------------- App Definitions -----------------------------------
#define APP_N_SAMPLES       (MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME)
#define APP_OUT_FREQ_HZ     (12000) // 12KHz
#define APP_SAMPLE_SECONDS  (5)
#define APP_N_FRAMES        (APP_OUT_FREQ_HZ * APP_SAMPLE_SECONDS / APP_N_SAMPLES)
#define APP_BUFF_SIZE       (APP_N_FRAMES * APP_N_SAMPLES)
#define APP_MIC_COUNT       (MIC_ARRAY_CONFIG_MIC_COUNT)
