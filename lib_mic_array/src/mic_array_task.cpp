// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <xcore/channel_streaming.h>
#include <xcore/interrupt.h>
#include <xcore/parallel.h>
#include <xcore/assert.h>
#include <platform.h>

#include "mic_array.h"
#include "mic_array/etc/filters_default.h"
#include "mic_array_task_internal.hpp"

TMicArray *g_mics = nullptr;  // Global mic array instance.
TMicArray_3stg_decimator *g_mics_3stg = nullptr;
bool use_3_stg_decimator = false;
// NOTE: g_mics must persist (remain non-null and its backing storage valid)
// until mic_array_start() completes. mic_array_start() performs shutdown and
// then sets g_mics back to nullptr.

#if !defined(__XS2A__)
////////////////////
// Mic array init //
////////////////////
void mic_array_init(pdm_rx_resources_t *pdm_res, const unsigned *channel_map, unsigned output_samp_freq)
{
  assert(g_mics == nullptr); // Mic array instance already initialised

  use_3_stg_decimator = false;

  unsigned stg2_decimation_factor = (pdm_res->pdm_freq/STAGE1_DEC_FACTOR)/output_samp_freq;
  assert ((output_samp_freq*STAGE1_DEC_FACTOR*stg2_decimation_factor) == pdm_res->pdm_freq); // assert if it doesn't divide cleanly
  // assert if unsupported decimation factor. (for example. when starting with a pdm_freq of 3.072MHz, supported
  // output sampling freqs are [48000, 32000, 16000]
  assert ((stg2_decimation_factor == 2) || (stg2_decimation_factor == 3) || (stg2_decimation_factor == 6));
  static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(TMicArray)];
  g_mics = new (mic_storage) TMicArray();
  init_mics_default_filter(g_mics, pdm_res, channel_map, stg2_decimation_factor);

}

template <typename TMics>
static inline void init_from_conf(TMics*& mics_ptr,
                                  uint8_t* storage,
                                  pdm_rx_resources_t* pdm_res,
                                  mic_array_conf_t* conf) {
  mics_ptr = new (storage) TMics();
  mics_ptr->Decimator.Init(conf->decimator_conf);
  mics_ptr->PdmRx.Init(pdm_res->p_pdm_mics, conf->pdmrx_conf);
  if (conf->pdmrx_conf.channel_map) {
    mics_ptr->PdmRx.MapChannels(conf->pdmrx_conf.channel_map);
  }
  mics_ptr->PdmRx.AssertOnDroppedBlock(false);
}

void mic_array_init_custom_filter(pdm_rx_resources_t* pdm_res,
                                         mic_array_conf_t* mic_array_conf)
{
  assert(pdm_res);
  assert(mic_array_conf);
  assert(g_mics == nullptr && g_mics_3stg == nullptr);
  static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(UAnyMicArray)];

  if(mic_array_conf->decimator_conf.num_filter_stages == 2)
  {
    use_3_stg_decimator = false;
    init_from_conf<TMicArray>(g_mics, mic_storage, pdm_res, mic_array_conf);
  }
  else if(mic_array_conf->decimator_conf.num_filter_stages == 3)
  {
    init_from_conf<TMicArray_3stg_decimator>(g_mics_3stg, mic_storage, pdm_res, mic_array_conf);
    use_3_stg_decimator = true;
  }
  // Configure and start clocks
  const unsigned divide = pdm_res->mclk_freq / pdm_res->pdm_freq;
  mic_array_resources_configure(pdm_res, divide);
  mic_array_pdm_clock_start(pdm_res);
}


/////////////////////
// Mic array start //
/////////////////////

// Parallel jobs for when XUA_PDM_MIC_USE_PDM_ISR == 0, run separate decimator and pdm rx tasks
DECLARE_JOB(default_ma_task_start_pdm, (TMicArray&));
void default_ma_task_start_pdm(TMicArray& mics){
  mics.PdmRx.ThreadEntry();
}

DECLARE_JOB(default_ma_task_start_decimator, (TMicArray&, chanend_t));
void default_ma_task_start_decimator(TMicArray& mics, chanend_t c_audio_frames){
  mics.ThreadEntry();
}

DECLARE_JOB(default_ma_task_start_pdm_3stg, (TMicArray_3stg_decimator&));
void default_ma_task_start_pdm_3stg(TMicArray_3stg_decimator& mics){
  mics.PdmRx.ThreadEntry();
}

DECLARE_JOB(default_ma_task_start_decimator_3stg, (TMicArray_3stg_decimator&, chanend_t));
void default_ma_task_start_decimator_3stg(TMicArray_3stg_decimator& mics, chanend_t c_audio_frames){
  mics.ThreadEntry();
}

#if defined(__XS3A__)
#define CLRSR(c)                asm volatile("clrsr %0" : : "n"(c));
#else
#define CLRSR(c)                ((void)0)
#warning "CLRSR not defined for this architecture."
#endif
#define CLEAR_KEDI()            CLRSR(XS1_SR_KEDI_MASK)

template <typename TMics>
void start_mics_with_pdm_isr(TMics* mics_ptr, chanend_t c_frames_out)
{
  assert(mics_ptr != nullptr);
  CLEAR_KEDI();
  mics_ptr->OutputHandler.FrameTx.SetChannel(c_frames_out);
  mics_ptr->PdmRx.AssertOnDroppedBlock(false);
  mics_ptr->PdmRx.InstallISR();
  mics_ptr->PdmRx.UnmaskISR();
  mics_ptr->ThreadEntry();
}

void mic_array_start(
    chanend_t c_frames_out)
{
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
  if (use_3_stg_decimator) {
    start_mics_with_pdm_isr<TMicArray_3stg_decimator>(g_mics_3stg, c_frames_out);
  }
  else {
    start_mics_with_pdm_isr<TMicArray>(g_mics, c_frames_out);
  }
#else
  if (use_3_stg_decimator) {
    assert(g_mics_3stg != nullptr); // Attempting to start mic_array before initialising it
    g_mics_3stg->OutputHandler.FrameTx.SetChannel(c_frames_out);
    PAR_JOBS(
      PJOB(default_ma_task_start_pdm_3stg, (*g_mics_3stg)),
      PJOB(default_ma_task_start_decimator_3stg, (*g_mics_3stg, c_frames_out)));
  }
  else
  {
    g_mics->OutputHandler.FrameTx.SetChannel(c_frames_out);
    PAR_JOBS(
      PJOB(default_ma_task_start_pdm, (*g_mics)),
      PJOB(default_ma_task_start_decimator, (*g_mics, c_frames_out)));
  }
#endif
  // shutdown
  if (use_3_stg_decimator) {
    g_mics_3stg->~TMicArray_3stg_decimator();
    g_mics_3stg = nullptr;
  }
  else {
    g_mics->~TMicArray();
    g_mics = nullptr;
  }
}
// Override pdm data port. Only used in tests where a chanend is used as a 'port' for input pdm data.
void _mic_array_override_pdm_port(chanend_t c_pdm)
{
  if (use_3_stg_decimator) {
    assert(g_mics_3stg != nullptr);
    g_mics_3stg->PdmRx.SetPort((port_t)c_pdm);
  } else {
    assert(g_mics != nullptr);
    g_mics->PdmRx.SetPort((port_t)c_pdm);
  }
}

// C wrapper
extern "C" void _mic_array_override_pdm_port_c(chanend_t c_pdm)
{
  _mic_array_override_pdm_port(c_pdm);
}

#endif // !defined(__XS2A__)
