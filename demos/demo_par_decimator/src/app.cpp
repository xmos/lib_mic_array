// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
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

#ifndef MIC_ARRAY_CONFIG_CLOCK_BLOCK_A
# define MIC_ARRAY_CONFIG_CLOCK_BLOCK_A         (XS1_CLKBLK_1)
#endif

#ifndef MIC_ARRAY_CONFIG_CLOCK_BLOCK_B 
# define MIC_ARRAY_CONFIG_CLOCK_BLOCK_B         (XS1_CLKBLK_2)
#endif

////// Additional macros derived from others

#define MIC_ARRAY_CONFIG_MCLK_DIVIDER           ((MIC_ARRAY_CONFIG_MCLK_FREQ)       \
                                                /(MIC_ARRAY_CONFIG_PDM_FREQ))
#define MIC_ARRAY_CONFIG_OUT_SAMPLE_RATE        ((MIC_ARRAY_CONFIG_PDM_FREQ)      \
                                                /(STAGE2_DEC_FACTOR))

////// Any Additional correctness checks


////// Allocate needed objects

pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                MIC_ARRAY_CONFIG_PORT_MCLK,
                                MIC_ARRAY_CONFIG_PORT_PDM_CLK,
                                MIC_ARRAY_CONFIG_PORT_PDM_DATA,
                                MIC_ARRAY_CONFIG_CLOCK_BLOCK_A,
                                MIC_ARRAY_CONFIG_CLOCK_BLOCK_B);

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
  printf("- MIC_ARRAY_CONFIG_CLOCK_BLOCK_A: " XSTR(MIC_ARRAY_CONFIG_CLOCK_BLOCK_A) "\n");
  printf("- MIC_ARRAY_CONFIG_CLOCK_BLOCK_B: " XSTR(MIC_ARRAY_CONFIG_CLOCK_BLOCK_B) "\n");
  printf("- MIC_ARRAY_CONFIG_MCLK_FREQ: " XSTR(MIC_ARRAY_CONFIG_MCLK_FREQ) "\n");
  printf("- MIC_ARRAY_CONFIG_PDM_FREQ: " XSTR(MIC_ARRAY_CONFIG_PDM_FREQ) "\n");
  printf("- MIC_ARRAY_CONFIG_MIC_COUNT: " XSTR(MIC_ARRAY_CONFIG_MIC_COUNT) "\n");
  printf("- MIC_ARRAY_CONFIG_USE_DDR: " XSTR(MIC_ARRAY_CONFIG_USE_DDR) "\n");
  printf("- MIC_ARRAY_CONFIG_PORT_MCLK: " XSTR(MIC_ARRAY_CONFIG_PORT_MCLK) "\n");
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
