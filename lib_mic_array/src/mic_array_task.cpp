// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <xcore/channel_streaming.h>
#include <xcore/interrupt.h>
#include <xcore/parallel.h>
#include <platform.h>
#include <assert.h>

#include "mic_array.h"
#include "mic_array/etc/filters_default.h"
#include "mic_array_task_internal.hpp"

TMicArray *g_mics = nullptr;

#ifdef __XS2A__ /* to get test_xs2_benign to compile */
#else
// Parallel jobs for when XUA_PDM_MIC_USE_PDM_ISR == 0, run separate decimator and pdm rx tasks
DECLARE_JOB(ma_task_start_pdm, (TMicArray&));
void ma_task_start_pdm(TMicArray& mics){
  mics.PdmRx.ThreadEntry();
}

DECLARE_JOB(ma_task_start_decimator, (TMicArray&, chanend_t));
void ma_task_start_decimator(TMicArray& mics, chanend_t c_audio_frames){
  mics.ThreadEntry();
}


void mic_array_init(pdm_rx_resources_t *pdm_res, const unsigned *channel_map, unsigned output_samp_freq)
{
  if (g_mics == nullptr) {
    unsigned stg2_decimation_factor = (pdm_res->pdm_freq/STAGE1_DEC_FACTOR)/output_samp_freq;
    assert ((output_samp_freq*STAGE1_DEC_FACTOR*stg2_decimation_factor) == pdm_res->pdm_freq); // assert if it doesn't divide cleanly
    // assert if unsupported decimation factor. (for example. when starting with a pdm_freq of 3.072MHz, supported
    // output sampling freqs are [48000, 32000, 16000]
    assert ((stg2_decimation_factor == 2) || (stg2_decimation_factor == 3) || (stg2_decimation_factor == 6));
    static uint32_t g_storage[(sizeof(TMicArray)+(sizeof(uint32_t) -1 ))/(sizeof(uint32_t))];
    create_mics_helper(g_storage, g_mics, pdm_res, channel_map, stg2_decimation_factor);
  }
}

void mic_array_start(
    chanend_t c_frames_out)
{
  assert(g_mics != nullptr); // Attempting to start mic_array before initialising it
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
  start_mics_with_pdm_isr(g_mics, c_frames_out);
#else
  g_mics->OutputHandler.FrameTx.SetChannel(c_frames_out);
  PAR_JOBS(
    PJOB(ma_task_start_pdm, (*g_mics)),
    PJOB(ma_task_start_decimator, (*g_mics, c_frames_out)));
#endif

  shutdown_mics_helper(g_mics);

  g_mics = nullptr;
}

// Override pdm data port. Only used in tests where a chanend is used as a 'port' for input pdm data.
void _mic_array_override_pdm_port(chanend_t c_pdm)
{
  assert(g_mics != nullptr); // Attempting to shutdown mic_array before initialising it
  g_mics->PdmRx.SetPort((port_t)c_pdm);
}
#endif
