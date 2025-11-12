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

TMicArray_stg2df_6* g_mics_df_6;
TMicArray_stg2df_3* g_mics_df_3;
TMicArray_stg2df_2* g_mics_df_2;
MicArrayKind g_kind = NONE;

#ifdef __XS2A__ /* to get test_xs2_benign to compile */
#else
// Parallel jobs for when XUA_PDM_MIC_USE_PDM_ISR == 0, run separate decimator and pdm rx tasks
DECLARE_JOB(ma_task_start_pdm_df_6, (TMicArray_stg2df_6&));
void ma_task_start_pdm_df_6(TMicArray_stg2df_6& mics){
  mics.PdmRx.ThreadEntry();
}

DECLARE_JOB(ma_task_start_decimator_df_6, (TMicArray_stg2df_6&, chanend_t));
void ma_task_start_decimator_df_6(TMicArray_stg2df_6& mics, chanend_t c_audio_frames){
  mics.ThreadEntry();
}

DECLARE_JOB(ma_task_start_pdm_df_3, (TMicArray_stg2df_3&));
void ma_task_start_pdm_df_3(TMicArray_stg2df_3& mics){
  mics.PdmRx.ThreadEntry();
}

DECLARE_JOB(ma_task_start_decimator_df_3, (TMicArray_stg2df_3&, chanend_t));
void ma_task_start_decimator_df_3(TMicArray_stg2df_3& mics, chanend_t c_audio_frames){
  mics.ThreadEntry();
}

DECLARE_JOB(ma_task_start_pdm_df_2, (TMicArray_stg2df_2&));
void ma_task_start_pdm_df_2(TMicArray_stg2df_2& mics){
  mics.PdmRx.ThreadEntry();
}

DECLARE_JOB(ma_task_start_decimator_df_2, (TMicArray_stg2df_2&, chanend_t));
void ma_task_start_decimator_df_2(TMicArray_stg2df_2& mics, chanend_t c_audio_frames){
  mics.ThreadEntry();
}


void mic_array_init(pdm_rx_resources_t *pdm_res, const unsigned *channel_map, unsigned output_samp_freq)
{
  if (g_kind == NONE) {
    unsigned stg2_decimation_factor = (pdm_res->pdm_freq/STAGE1_DEC_FACTOR)/output_samp_freq;
    assert ((output_samp_freq*STAGE1_DEC_FACTOR*stg2_decimation_factor) == pdm_res->pdm_freq); // assert if it doesnt divide cleanly
    // assert if unsupported decimation factor. (for example. when starting with a pdm_freq of 3.072MHz, supported
    // output sampling freqs are [48000, 32000, 16000]
    assert ((stg2_decimation_factor == 2) || (stg2_decimation_factor == 3) || (stg2_decimation_factor == 6));
    static uint32_t g_storage[(sizeof(UAnyMicArray)+(sizeof(uint32_t) -1 ))/(sizeof(uint32_t))];
    switch(stg2_decimation_factor)
    {
      case 6:
        create_mics_helper<TMicArray_stg2df_6>(g_storage, g_mics_df_6, pdm_res, channel_map, stg2_decimation_factor, DF_6);
        break;
      case 3:
        create_mics_helper<TMicArray_stg2df_3>(g_storage, g_mics_df_3, pdm_res, channel_map, stg2_decimation_factor, DF_3);
        break;
      case 2:
        create_mics_helper<TMicArray_stg2df_2>(g_storage, g_mics_df_2, pdm_res, channel_map, stg2_decimation_factor, DF_2);
        break;
      default:
        assert(0); // unsupported output_samp_freq
        break;
    }
  }
}

void mic_array_start(
    chanend_t c_frames_out)
{
  switch (g_kind) {
    case DF_6:
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
      start_mics_with_pdm_isr(g_mics_df_6, c_frames_out);
#else
    g_mics_df_6->OutputHandler.FrameTx.SetChannel(c_frames_out);
    PAR_JOBS(
      PJOB(ma_task_start_pdm_df_6, (*g_mics_df_6)),
      PJOB(ma_task_start_decimator_df_6, (*g_mics_df_6, c_frames_out)));
#endif
      break;
    case DF_3:
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
      start_mics_with_pdm_isr(g_mics_df_3, c_frames_out);
#else
      g_mics_df_3->OutputHandler.FrameTx.SetChannel(c_frames_out);
      PAR_JOBS(
        PJOB(ma_task_start_pdm_df_3, (*g_mics_df_3)),
        PJOB(ma_task_start_decimator_df_3, (*g_mics_df_3, c_frames_out)));
#endif
      break;
    case DF_2:
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
      start_mics_with_pdm_isr(g_mics_df_2, c_frames_out);
#else
      g_mics_df_2->OutputHandler.FrameTx.SetChannel(c_frames_out);
      PAR_JOBS(
        PJOB(ma_task_start_pdm_df_2, (*g_mics_df_2)),
        PJOB(ma_task_start_decimator_df_2, (*g_mics_df_2, c_frames_out)));
#endif
      break;
    case NONE:
        assert(0); // Attempting to start mic_array before initialising it
        break;
  }
  // call destructors etc before exiting
  switch (g_kind) {
    case DF_6:
      shutdown_mics_helper<TMicArray_stg2df_6>(g_mics_df_6);
      break;
    case DF_3:
      shutdown_mics_helper<TMicArray_stg2df_3>(g_mics_df_3);
      break;
    case DF_2:
      shutdown_mics_helper<TMicArray_stg2df_2>(g_mics_df_2);
      break;
    case NONE:
      assert(0); // Attempting to shutdown mic_array before initialising it
  }
  g_kind = NONE;
}

// Override pdm data port. Only used in tests where a chanend is used as a 'port' for input pdm data.
void _mic_array_override_pdm_port(chanend_t c_pdm)
{
  switch (g_kind) {
    case DF_6:
      g_mics_df_6->PdmRx.SetPort((port_t)c_pdm);
      break;
    case DF_3:
      g_mics_df_3->PdmRx.SetPort((port_t)c_pdm);
      break;
    case DF_2:
      g_mics_df_2->PdmRx.SetPort((port_t)c_pdm);
      break;
    case NONE:
      assert(0); // Attempting to shutdown mic_array before initialising it
  }

}
#endif
