// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdbool.h>
#include <xcore/assert.h>
#include <xcore/parallel.h>
#include <platform.h>

#include "mic_array.h"
#include "mic_array_task_internal.hpp"

////////////////////
// Mic array init //
////////////////////
void mic_array_init(pdm_rx_resources_t *pdm_res, const unsigned *channel_map, unsigned output_samp_freq)
{
  unsigned stg2_decimation_factor = (pdm_res->pdm_freq/STAGE1_DEC_FACTOR)/output_samp_freq;
  assert ((output_samp_freq*STAGE1_DEC_FACTOR*stg2_decimation_factor) == pdm_res->pdm_freq); // assert if it doesn't divide cleanly
  // assert if unsupported decimation factor. (for example. when starting with a pdm_freq of 3.072MHz, supported
  // output sampling freqs are [48000, 32000, 16000]
  assert ((stg2_decimation_factor == 2) || (stg2_decimation_factor == 3) || (stg2_decimation_factor == 6));

  bool use_3_stg_decimator = false;
  init_mic_array_storage(use_3_stg_decimator);
  init_mics_default_filter(pdm_res, channel_map, stg2_decimation_factor);
}

void mic_array_init_custom_filter(pdm_rx_resources_t* pdm_res, mic_array_conf_t* mic_array_conf)
{
  assert(pdm_res);
  assert(mic_array_conf);
  assert(mic_array_conf->decimator_conf.num_filter_stages == 2 ||
         mic_array_conf->decimator_conf.num_filter_stages == 3);

  init_mic_array_storage(mic_array_conf->decimator_conf.num_filter_stages == 3);
  init_mics_custom_filter(pdm_res, mic_array_conf);

  // Configure and start clocks
  const unsigned divide = pdm_res->mclk_freq / pdm_res->pdm_freq;
  mic_array_resources_configure(pdm_res, divide);
  mic_array_pdm_clock_start(pdm_res);
}

/////////////////////
// Mic array start //
/////////////////////

// Parallel jobs for when XUA_PDM_MIC_USE_PDM_ISR == 0, run separate decimator and pdm rx tasks
DECLARE_JOB(default_ma_task_start_pdm, (void));
void default_ma_task_start_pdm(void)
{
  start_pdm_task();
}

DECLARE_JOB(default_ma_task_start_decimator, (chanend_t));
void default_ma_task_start_decimator(chanend_t c_audio_frames)
{
  start_decimator_task();
}

DECLARE_JOB(default_ma_task_start_pdm_3stg, (void));
void default_ma_task_start_pdm_3stg(void)
{
  start_pdm_task_3stg();
}

DECLARE_JOB(default_ma_task_start_decimator_3stg, (chanend_t));
void default_ma_task_start_decimator_3stg(chanend_t c_audio_frames)
{
  start_decimator_task_3stg();
}

void mic_array_start(chanend_t c_frames_out)
{
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
  start_mic_array_pdm_isr(c_frames_out);
#else
  set_output_channel(c_frames_out);
  bool use_3_stg_decimator = get_decimator_stg_count();
  if (use_3_stg_decimator) {
    PAR_JOBS(
      PJOB(default_ma_task_start_pdm_3stg, ()),
      PJOB(default_ma_task_start_decimator_3stg, ()));
  } else {
    PAR_JOBS(
      PJOB(default_ma_task_start_pdm, ()),
      PJOB(default_ma_task_start_decimator, ()));
  }
#endif // MIC_ARRAY_CONFIG_USE_PDM_ISR

  shutdown_mic_array();
}
