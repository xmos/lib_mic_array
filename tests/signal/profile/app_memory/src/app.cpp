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
  static int32_t filter_state_df_2[APP_N_MICS][MIC_ARRAY_48K_STAGE_2_TAP_COUNT];
  mic_array_decimator_conf_t decimator_conf;
  memset(&decimator_conf, 0, sizeof(decimator_conf));
  decimator_conf.mic_count = APP_N_MICS;
  decimator_conf.filter_conf[0].coef = (int32_t*)stage1_48k_coefs;
  decimator_conf.filter_conf[0].num_taps = 256;
  decimator_conf.filter_conf[0].decimation_factor = 32;
  decimator_conf.filter_conf[0].state = (int32_t*)stg1_filter_state;
  decimator_conf.filter_conf[0].state_size = 8;

  decimator_conf.filter_conf[1].coef = (int32_t*)stage2_48k_coefs;
  decimator_conf.filter_conf[1].decimation_factor = STAGE2_DEC_FACTOR_48KHZ;
  decimator_conf.filter_conf[1].num_taps = MIC_ARRAY_48K_STAGE_2_TAP_COUNT;
  decimator_conf.filter_conf[1].shr = stage2_48k_shift;
  decimator_conf.filter_conf[1].state_size = decimator_conf.filter_conf[1].num_taps;
  decimator_conf.filter_conf[1].state = (int32_t*)filter_state_df_2;

  mics.Decimator.Init_new(decimator_conf);

  static uint32_t pdmrx_out_block_df_2[APP_N_MICS][STAGE2_DEC_FACTOR_48KHZ];
  static uint32_t __attribute__((aligned (8))) pdmrx_out_block_double_buf_df_2[2][APP_N_MICS_IN * STAGE2_DEC_FACTOR_48KHZ];

  pdm_rx_config_t pdm_rx_config;
  pdm_rx_config.num_mics = APP_N_MICS;
  pdm_rx_config.num_mics_in = APP_N_MICS_IN;
  pdm_rx_config.out_block_size = STAGE2_DEC_FACTOR_48KHZ;
  pdm_rx_config.out_block = (uint32_t*)pdmrx_out_block_df_2;
  pdm_rx_config.out_block_double_buf = (uint32_t*)pdmrx_out_block_double_buf_df_2;

  mics.PdmRx.Init_new(pdm_res.p_pdm_mics, pdm_rx_config);
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

