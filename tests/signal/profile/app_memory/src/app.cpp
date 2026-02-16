// Copyright 2023-2026 XMOS LIMITED.
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
#if (APP_SAMP_FREQ != 16000)
  #error "App built for 16KHz. Compile with -DAPP_SAMP_FREQ=16000"
#endif

#ifndef APP_N_MICS_IN
  #define APP_N_MICS_IN APP_N_MICS
#endif

#if defined(__XS3A__)
#define CLEAR_KEDI() asm volatile("clrsr %0" : : "n"(XS1_SR_KEDI_MASK));
#else
#warning "CLEAR_KEDI not defined for this architecture."
#endif

using TMicArray = mic_array::MicArray<APP_N_MICS,
                          mic_array::TwoStageDecimator<APP_N_MICS>,
                          mic_array::StandardPdmRxService<APP_N_MICS_IN,
                                                          APP_N_MICS>,
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
  static int32_t stg1_filter_state[APP_N_MICS][8];
  static int32_t filter_state_df_2[APP_N_MICS][STAGE2_TAP_COUNT];
  mic_array_decimator_conf_t decimator_conf;
  mic_array_filter_conf_t filter_conf[2];
  memset(&decimator_conf, 0, sizeof(decimator_conf));

  decimator_conf.filter_conf = &filter_conf[0];
  decimator_conf.num_filter_stages = 2;
  filter_conf[0].coef = (int32_t*)stage1_coef;
  filter_conf[0].num_taps = 256;
  filter_conf[0].decimation_factor = 32;
  filter_conf[0].state = (int32_t*)stg1_filter_state;
  filter_conf[0].state_words_per_channel = filter_conf[0].num_taps/32;

  filter_conf[1].coef = (int32_t*)stage2_coef;
  filter_conf[1].decimation_factor = STAGE2_DEC_FACTOR;
  filter_conf[1].num_taps = STAGE2_TAP_COUNT;
  filter_conf[1].shr = stage2_shr;
  filter_conf[1].state_words_per_channel = decimator_conf.filter_conf[1].num_taps;
  filter_conf[1].state = (int32_t*)filter_state_df_2;

  mics.Decimator.Init(decimator_conf);

  static uint32_t pdmrx_out_block_df_2[APP_N_MICS][STAGE2_DEC_FACTOR];
  static uint32_t __attribute__((aligned (8))) pdmrx_out_block_double_buf_df_2[2][APP_N_MICS_IN * STAGE2_DEC_FACTOR];

  pdm_rx_conf_t pdm_rx_config;
  pdm_rx_config.pdm_out_words_per_channel = STAGE2_DEC_FACTOR;
  pdm_rx_config.pdm_out_block = (uint32_t*)pdmrx_out_block_df_2;
  pdm_rx_config.pdm_in_double_buf = (uint32_t*)pdmrx_out_block_double_buf_df_2;

  mics.PdmRx.Init(pdm_res.p_pdm_mics, pdm_rx_config);
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
