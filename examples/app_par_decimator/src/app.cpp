// Copyright 2023-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <platform.h>
#include <xcore/channel_streaming.h>
#include <xcore/interrupt.h>

#include "app_config.h"
#include "app_mic_array.hpp"

#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

#ifndef STR
#define STR(s) #s
#endif

#ifndef XSTR
#define XSTR(s) STR(s)
#endif

#ifndef MIC_ARRAY_CONFIG_USE_DC_ELIMINATION
# define MIC_ARRAY_CONFIG_USE_DC_ELIMINATION    (1)
#endif

////// Additional macros derived from others

#define MIC_ARRAY_CONFIG_MCLK_DIVIDER           ((MCLK_FREQ)       \
                                                /(PDM_FREQ))

////// Any Additional correctness checks


////// Allocate needed objects

pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                APP_PORT_MCLK,
                                APP_PORT_PDM_CLK,
                                APP_PORT_PDM_DATA,
                                MCLK_FREQ,
                                PDM_FREQ,
                                XS1_CLKBLK_1,
                                XS1_CLKBLK_2);

using TMicArray = par_mic_array::ParMicArray<
                        MIC_ARRAY_CONFIG_MIC_COUNT,
                        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                        MIC_ARRAY_CONFIG_USE_DC_ELIMINATION>;

TMicArray mics;

MA_C_API
void app_mic_array_init()
{
  printf("MIC CONFIG:\n");
  printf("- MIC_ARRAY_TILE: " XSTR(MIC_ARRAY_TILE) "\n");
  printf("- MIC_ARRAY_CONFIG_CLOCK_BLOCK_A: " XSTR(XS1_CLKBLK_1) "\n");
  printf("- MIC_ARRAY_CONFIG_CLOCK_BLOCK_B: " XSTR(XS1_CLKBLK_2) "\n");
  printf("- MIC_ARRAY_CONFIG_MCLK_FREQ: " XSTR(MCLK_FREQ) "\n");
  printf("- MIC_ARRAY_CONFIG_PDM_FREQ: " XSTR(PDM_FREQ) "\n");
  printf("- MIC_ARRAY_CONFIG_MIC_COUNT: " XSTR(MIC_ARRAY_CONFIG_MIC_COUNT) "\n");
  printf("- MIC_ARRAY_CONFIG_USE_DDR: " XSTR(MIC_ARRAY_CONFIG_USE_DDR) "\n");
  printf("- MIC_ARRAY_CONFIG_PORT_MCLK: " XSTR(APP_PORT_MCLK) "\n");
  printf("- MIC_ARRAY_CONFIG_PORT_PDM_CLK: " XSTR(MIC_ARRAY_CONFIG_PORT_PDM_CLK) "\n");
  printf("- MIC_ARRAY_CONFIG_PORT_PDM_DATA: " XSTR(MIC_ARRAY_CONFIG_PORT_PDM_DATA) "\n");
  printf("- MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME: " XSTR(MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME) "\n");

  mics.Init();
  mics.SetPort(pdm_res.p_pdm_mics);
  mic_array_resources_configure(&pdm_res, MIC_ARRAY_CONFIG_MCLK_DIVIDER);
  mic_array_pdm_clock_start(&pdm_res);
}

MA_C_API
void app_mic_array_task(chanend_t c_frames_out)
{
  mics.SetOutputChannel(c_frames_out);

  mics.InstallPdmRxISR();
  mics.UnmaskPdmRxISR();

  mics.ThreadEntry();
}

MA_C_API
void app_mic_array_assertion_disable()
{
  mics.PdmRx.AssertOnDroppedBlock(false);
}

MA_C_API
void app_mic_array_assertion_enable()
{
  mics.PdmRx.AssertOnDroppedBlock(true);
}
