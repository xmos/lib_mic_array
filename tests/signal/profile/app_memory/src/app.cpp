// Copyright 2023-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <platform.h>
#include <xcore/channel_streaming.h>
#include <xcore/interrupt.h>
#include <xcore/parallel.h>

#include "app_config.h"

#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

#if !USE_DEFAULT_API

#ifndef STR
#define STR(s) #s
#endif

#ifndef XSTR
#define XSTR(s) STR(s)
#endif


////// Additional macros derived from others
#define MCLK_FREQ (24576000)
#define PDM_FREQ (3072000)
#define MCLK_DIVIDER          ((MCLK_FREQ) /(PDM_FREQ))


////// Allocate needed objects

pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                PORT_MCLK_IN,
                                PORT_PDM_CLK,
                                PORT_PDM_DATA,
                                MCLK_FREQ,
                                PDM_FREQ,
                                XS1_CLKBLK_1,
                                XS1_CLKBLK_2);


#define APP_N_MICS      (MIC_ARRAY_CONFIG_MIC_COUNT)
#define APP_USE_DC_ELIMINATION  (MIC_ARRAY_CONFIG_USE_DC_ELIMINATION)
#if (APP_SAMP_FREQ != 48000)
  #error "App built for 48KHz. Compile with -DAPP_SAMP_FREQ=48000"
#endif

#ifndef APP_N_MICS_IN
  #define APP_N_MICS_IN APP_N_MICS
#endif
#define STAGE2_DEC_FACTOR_48KHZ   2
#define CLRSR(c)                asm volatile("clrsr %0" : : "n"(c));
#define CLEAR_KEDI()            CLRSR(XS1_SR_KEDI_MASK)

using TMicArray = mic_array::MicArray<APP_N_MICS,
                          mic_array::TwoStageDecimator<APP_N_MICS,
                                              STAGE2_DEC_FACTOR_48KHZ,
                                              MIC_ARRAY_48K_STAGE_2_TAP_COUNT>,
                          mic_array::StandardPdmRxService<APP_N_MICS_IN,
                                                          APP_N_MICS,
                                                          STAGE2_DEC_FACTOR_48KHZ>,
                          typename std::conditional<APP_USE_DC_ELIMINATION,
                                              mic_array::DcoeSampleFilter<APP_N_MICS>,
                                              mic_array::NopSampleFilter<APP_N_MICS>>::type,
                          mic_array::FrameOutputHandler<APP_N_MICS,
                                                        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                                        mic_array::ChannelFrameTransmitter>>;
TMicArray mics;

MA_C_API
void app_mic_array_init()
{
  mics.Decimator.Init((uint32_t*) stage1_48k_coefs, stage2_48k_coefs, stage2_48k_shift);
  mics.PdmRx.Init(pdm_res.p_pdm_mics);
  mic_array_resources_configure(&pdm_res, MCLK_DIVIDER);
  mic_array_pdm_clock_start(&pdm_res);
}

DECLARE_JOB(ma_task_start_pdm, (TMicArray&));
void ma_task_start_pdm(TMicArray& m){
  m.PdmRx.ThreadEntry();
}

DECLARE_JOB(ma_task_start_decimator, (TMicArray&, chanend_t));
void ma_task_start_decimator(TMicArray& m, chanend_t c_audio_frames){
  m.ThreadEntry();
}

MA_C_API
void app_mic_array_task(chanend_t c_frames_out)
{
#if APP_USE_PDMRX_ISR
  CLEAR_KEDI()

  mics.OutputHandler.FrameTx.SetChannel(c_frames_out);
  // Setup the ISR and enable. Then start decimator.
  mics.PdmRx.AssertOnDroppedBlock(false);
  mics.PdmRx.InstallISR();
  mics.PdmRx.UnmaskISR();
  mics.ThreadEntry();
#else
  mics.OutputHandler.FrameTx.SetChannel(c_frames_out);
  PAR_JOBS(
      PJOB(ma_task_start_pdm, (mics)),
      PJOB(ma_task_start_decimator, (mics, c_frames_out))
    );
#endif
}
#endif

