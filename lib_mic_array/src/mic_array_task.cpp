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

TMicArray *g_mics = nullptr;  // Global mic array instance.
// NOTE: g_mics must persist (remain non-null and its backing storage valid)
// until mic_array_start() completes. mic_array_start() performs shutdown and
// then sets g_mics back to nullptr.

#ifdef __XS2A__ /* to get test_xs2_benign to compile */
#else
// Parallel jobs for when XUA_PDM_MIC_USE_PDM_ISR == 0, run separate decimator and pdm rx tasks
DECLARE_JOB(default_ma_task_start_pdm, (TMicArray&));
void default_ma_task_start_pdm(TMicArray& mics){
  mics.PdmRx.ThreadEntry();
}

DECLARE_JOB(default_ma_task_start_decimator, (TMicArray&, chanend_t));
void default_ma_task_start_decimator(TMicArray& mics, chanend_t c_audio_frames){
  mics.ThreadEntry();
}


void mic_array_init(pdm_rx_resources_t *pdm_res, const unsigned *channel_map, unsigned output_samp_freq)
{
  assert(g_mics == nullptr); // Mic array instance already initialised

  unsigned stg2_decimation_factor = (pdm_res->pdm_freq/STAGE1_DEC_FACTOR)/output_samp_freq;
  assert ((output_samp_freq*STAGE1_DEC_FACTOR*stg2_decimation_factor) == pdm_res->pdm_freq); // assert if it doesn't divide cleanly
  // assert if unsupported decimation factor. (for example. when starting with a pdm_freq of 3.072MHz, supported
  // output sampling freqs are [48000, 32000, 16000]
  assert ((stg2_decimation_factor == 2) || (stg2_decimation_factor == 3) || (stg2_decimation_factor == 6));
  static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(TMicArray)];
  g_mics = new (mic_storage) TMicArray();
  init_mics_default_filter(g_mics, pdm_res, channel_map, stg2_decimation_factor);

}

void mic_array_init_custom_filter(pdm_rx_resources_t* pdm_res,
                                         mic_array_conf_t* mic_array_conf)
{
  assert(pdm_res);
  assert(mic_array_conf);
  assert(g_mics == nullptr); // Mic array instance already initialised
  static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(TMicArray)];
  g_mics = new (mic_storage) TMicArray();
  // Configure decimator with app-provided filters/state
  g_mics->Decimator.Init(mic_array_conf->decimator_conf);

  // Configure PDM RX with app-provided buffers/mapping
  g_mics->PdmRx.Init(pdm_res->p_pdm_mics, mic_array_conf->pdmrx_conf);
  if (mic_array_conf->pdmrx_conf.channel_map) {
    g_mics->PdmRx.MapChannels(mic_array_conf->pdmrx_conf.channel_map);
  }
  g_mics->PdmRx.AssertOnDroppedBlock(false);

  // Configure and start clocks
  const unsigned divide = pdm_res->mclk_freq / pdm_res->pdm_freq;
  mic_array_resources_configure(pdm_res, divide);
  mic_array_pdm_clock_start(pdm_res);
}

#define CLRSR(c)                asm volatile("clrsr %0" : : "n"(c));
#define CLEAR_KEDI()            CLRSR(XS1_SR_KEDI_MASK)

void mic_array_start(
    chanend_t c_frames_out)
{
  assert(g_mics != nullptr); // Attempting to start mic_array before initialising it
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
  //clear KEDI since pdm_rx_isr assumes single issue and the module is compiled with dual issue.
  CLEAR_KEDI()
  g_mics->OutputHandler.FrameTx.SetChannel(c_frames_out);
  // Setup the ISR and enable. Then start decimator.
  g_mics->PdmRx.AssertOnDroppedBlock(false);
  g_mics->PdmRx.InstallISR();
  g_mics->PdmRx.UnmaskISR();
  g_mics->ThreadEntry();
#else
  g_mics->OutputHandler.FrameTx.SetChannel(c_frames_out);
  PAR_JOBS(
    PJOB(default_ma_task_start_pdm, (*g_mics)),
    PJOB(default_ma_task_start_decimator, (*g_mics, c_frames_out)));
#endif

  g_mics->~TMicArray();
  g_mics = nullptr;
}

// Override pdm data port. Only used in tests where a chanend is used as a 'port' for input pdm data.
void _mic_array_override_pdm_port(chanend_t c_pdm)
{
  assert(g_mics != nullptr); // Attempting to shutdown mic_array before initialising it
  g_mics->PdmRx.SetPort((port_t)c_pdm);
}
#endif
