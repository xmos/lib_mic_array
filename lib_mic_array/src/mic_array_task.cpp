// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <xcore/channel_streaming.h>
#include <xcore/interrupt.h>
#include <xcore/assert.h>
#include <platform.h>

#include "mic_array.h"
#include "mic_array/etc/filters_default.h"
#include "mic_array_task_internal.hpp"

static TMicArray *s_mics = nullptr;
static TMicArray1MicOverride *s_mics_1mic_override = nullptr;
static bool s_1mic_override_active = false;
// NOTE: s_mics must persist (remain non-null with its backing storage valid)
// until mic_array_start() completes. mic_array_start() performs shutdown and
// then sets s_mics back to nullptr.

#if !defined (__XS2A__)

////////////////////
// Mic array init //
////////////////////
void init_1mic_override(void)
{
  // init_1mic_override() should be called before initialising the mic array
  assert((s_mics == nullptr) && (s_mics_1mic_override == nullptr)); // Mic array instance already initialised
  s_1mic_override_active = true;
}

void init_mic_array_storage()
{
  assert((s_mics == nullptr) && (s_mics_1mic_override == nullptr)); // Mic array instance already initialised
  if(s_1mic_override_active) {
    static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(TMicArray1MicOverride)];
    s_mics_1mic_override = new (mic_storage) TMicArray1MicOverride();
  } else {
    static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(TMicArray)];
     s_mics = new (mic_storage) TMicArray();
  }
}

template <typename TMics>
static inline void init_from_conf(TMics*& mics_ptr, pdm_rx_resources_t* pdm_res, mic_array_conf_t* conf)
{
  mics_ptr->Decimator.Init(conf->decimator_conf, conf->pdmrx_conf.pdm_out_words_per_channel);
  mics_ptr->PdmRx.Init(pdm_res->p_pdm_mics, conf->pdmrx_conf);
  if (conf->pdmrx_conf.channel_map) {
    mics_ptr->PdmRx.MapChannels(conf->pdmrx_conf.channel_map);
  }
  mics_ptr->PdmRx.AssertOnDroppedBlock(false);
}

void init_mics_default_filter(pdm_rx_resources_t* pdm_res, const unsigned* channel_map, unsigned stg2_dec_factor)
{
  static int32_t stg1_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][8];
  mic_array_conf_t mic_array_conf;
  memset(&mic_array_conf, 0, sizeof(mic_array_conf_t));
  mic_array_filter_conf_t filter_conf[2] = {{0}};

  // decimator
  mic_array_conf.decimator_conf.filter_conf = &filter_conf[0];
  mic_array_conf.decimator_conf.num_filter_stages = 2;
  //filter stage 1
  filter_conf[0].coef = (int32_t*)stage_1_filter(stg2_dec_factor);
  filter_conf[0].num_taps = 256;
  filter_conf[0].decimation_factor = 32;
  filter_conf[0].shr = 0;
  filter_conf[0].state_words_per_channel = filter_conf[0].num_taps/32;
  filter_conf[0].state = (int32_t*)stg1_filter_state;

  // filter stage 2
  filter_conf[1].coef = (int32_t*)stage_2_filter(stg2_dec_factor);
  filter_conf[1].num_taps = stage_2_num_taps(stg2_dec_factor);
  filter_conf[1].decimation_factor = stg2_dec_factor;
  filter_conf[1].shr = stage_2_shift(stg2_dec_factor);
  filter_conf[1].state_words_per_channel = mic_array_conf.decimator_conf.filter_conf[1].num_taps;
  filter_conf[1].state = stage_2_state_memory(stg2_dec_factor);

  mic_array_conf.pdmrx_conf.pdm_out_words_per_channel = stg2_dec_factor;
  mic_array_conf.pdmrx_conf.pdm_out_block = get_pdm_rx_out_block(stg2_dec_factor);
  mic_array_conf.pdmrx_conf.pdm_in_double_buf = get_pdm_rx_out_block_double_buf(stg2_dec_factor);
  mic_array_conf.pdmrx_conf.channel_map = channel_map;

  if(s_1mic_override_active) {
    assert(mic_array_conf.pdmrx_conf.pdm_out_words_per_channel <= TMicArray::MAX_PDM_OUT_WORDS_PER_CHANNEL);
    init_from_conf<TMicArray1MicOverride>(s_mics_1mic_override, pdm_res, &mic_array_conf);
  }
  else {
    init_from_conf<TMicArray>(s_mics, pdm_res, &mic_array_conf);
  }
}

void init_mics_custom_filter(pdm_rx_resources_t* pdm_res, mic_array_conf_t* mic_array_conf)
{
  if(s_1mic_override_active) {
    assert(mic_array_conf->pdmrx_conf.pdm_out_words_per_channel <= TMicArray::MAX_PDM_OUT_WORDS_PER_CHANNEL);
    init_from_conf<TMicArray1MicOverride>(s_mics_1mic_override, pdm_res, mic_array_conf);
  }
  else {
    init_from_conf<TMicArray>(s_mics, pdm_res, mic_array_conf);
  }
}

/////////////////////
// Mic array start //
/////////////////////
void assert_mic_array_start_ready(void) {
  if(s_1mic_override_active) {
    assert(s_mics_1mic_override != nullptr);
  }
  else
  {
    assert(s_mics != nullptr);
  }
}

void set_output_channel(chanend_t c_frames_out)
{
  if(s_1mic_override_active) {
    s_mics_1mic_override->OutputHandler.FrameTx.SetChannel(c_frames_out);
  }
  else {
    s_mics->OutputHandler.FrameTx.SetChannel(c_frames_out);
  }
}

#if defined(__XS3A__)
#define CLEAR_KEDI() asm volatile("clrsr %0" : : "n"(XS1_SR_KEDI_MASK));
#elif defined(__VX4B__)
// VX4 processors do not have a dual-issue mode due to VLIW instructions.
// Remove any definition of CLEAR_KEDI so any acciddental use of it will be caught at compile time.
#undef CLEAR_KEDI
#else
#undef CLEAR_KEDI // Catch at compile time if attempting to use CLEAR_KEDI on unsupported architectures.
#endif

template <typename TMics>
void start_mics_with_pdm_isr(TMics* mics_ptr, chanend_t c_frames_out)
{
  #if defined(__XS3A__)
  CLEAR_KEDI(); // Disable dual-issue mode on XS3A processors. VX4 processors do not have a dual-issue mode.
  #endif

  mics_ptr->OutputHandler.FrameTx.SetChannel(c_frames_out);
  mics_ptr->PdmRx.AssertOnDroppedBlock(false);
  mics_ptr->PdmRx.InstallISR();
  mics_ptr->PdmRx.UnmaskISR();
  mics_ptr->ThreadEntry();
}

void start_mic_array_pdm_isr(chanend_t c_frames_out)
{
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
  if(s_1mic_override_active) {
    start_mics_with_pdm_isr<TMicArray1MicOverride>(s_mics_1mic_override, c_frames_out);
  }
  else {
    start_mics_with_pdm_isr<TMicArray>(s_mics, c_frames_out);
  }
#endif
}

// Helper functions for starting separate tasks
void start_pdm_task(void)
{
  if(s_1mic_override_active) {
    s_mics_1mic_override->PdmRx.ThreadEntry();
  }
  else {
    s_mics->PdmRx.ThreadEntry();
  }
}

void start_decimator_task()
{
  if(s_1mic_override_active) {
    s_mics_1mic_override->ThreadEntry();
  }
  else {
    s_mics->ThreadEntry();
  }
}

////////////////////////
// Mic array shutdown //
////////////////////////

void shutdown_mic_array(void)
{
  if (s_1mic_override_active) {
    s_mics_1mic_override->~TMicArray1MicOverride();
  }
  else {
    s_mics->~TMicArray();
  }

  s_mics_1mic_override = nullptr;
  s_mics = nullptr;
  s_1mic_override_active = false;
}


// Override pdm data port. Only used in tests where a chanend is used as a 'port' for input pdm data.
void _mic_array_override_pdm_port(chanend_t c_pdm)
{
  if(s_1mic_override_active) {
    s_mics_1mic_override->PdmRx.SetPort((port_t)c_pdm);
  }
  else {
    s_mics->PdmRx.SetPort((port_t)c_pdm);
  }
}

// C wrapper
MA_C_API
void _mic_array_override_pdm_port_c(chanend_t c_pdm)
{
  _mic_array_override_pdm_port(c_pdm);
}

#endif // !defined(__XS2A__)
