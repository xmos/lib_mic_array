// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

// -------------------- Frecuency and Port definitions --------------------
#define MIC_ARRAY_CONFIG_MCLK_FREQ  (24576000)        /* 24 MHz */
#define MIC_ARRAY_CONFIG_PDM_FREQ   (768000)         /* 768 KHz */
#define MIC_ARRAY_CONFIG_PORT_MCLK XS1_PORT_1D       /* X0D11, J14 - Pin 15, '11' */
#define MIC_ARRAY_CONFIG_PORT_PDM_CLK PORT_MIC_CLK   /* X0D00, J14 - Pin 2, '00' */
#define MIC_ARRAY_CONFIG_PORT_PDM_DATA PORT_MIC_DATA /* X0D14..X0D21 | J14 - Pin 3,5,12,14 and Pin 6,7,10,11 */
#define MIC_ARRAY_CONFIG_CLOCK_BLOCK_A XS1_CLKBLK_2

// ------------------------- App Definitions -----------------------------------
#define APP_N_SAMPLES (320)
#define APP_OUT_FREQ_HZ (12000) // 12KHz
#define APP_SAMPLE_SECONDS (2)
#define APP_N_FRAMES (APP_OUT_FREQ_HZ * APP_SAMPLE_SECONDS / APP_N_SAMPLES)
#define APP_BUFF_SIZE (APP_N_FRAMES * APP_N_SAMPLES)
#define APP_MIC_COUNT (MIC_ARRAY_CONFIG_MIC_COUNT)
