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
static TMicArray_3stg_decimator *s_mics_3stg = nullptr;
static bool s_use_3_stg_decimator = false;
// NOTE: s_mics or s_mics_3stg must persist (remain non-null with its backing storage valid)
// until mic_array_start() completes. mic_array_start() performs shutdown and
// then sets s_mics or s_mics_3stg back to nullptr.

#if defined (__XS3A__) || defined (__VX4B__)
/////////////////////////////
// Static variable getters //
/////////////////////////////
bool get_decimator_stg_count(void)
{
  return s_use_3_stg_decimator;
}

////////////////////
// Mic array init //
////////////////////
void init_mics_default_filter(pdm_rx_resources_t* pdm_res, const unsigned* channel_map, unsigned stg2_dec_factor)
{
  static int32_t stg1_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][8];
  mic_array_decimator_conf_t decimator_conf;
  memset(&decimator_conf, 0, sizeof(decimator_conf));
  mic_array_filter_conf_t filter_conf[2] = {{0}};

  // decimator
  decimator_conf.filter_conf = &filter_conf[0];
  decimator_conf.num_filter_stages = 2;
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
  filter_conf[1].state_words_per_channel = decimator_conf.filter_conf[1].num_taps;
  filter_conf[1].state = stage_2_state_memory(stg2_dec_factor);

  s_mics->Decimator.Init(decimator_conf);

  pdm_rx_conf_t pdm_rx_config;
  pdm_rx_config.pdm_out_words_per_channel = stg2_dec_factor;
  pdm_rx_config.pdm_out_block = get_pdm_rx_out_block(stg2_dec_factor);
  pdm_rx_config.pdm_in_double_buf = get_pdm_rx_out_block_double_buf(stg2_dec_factor);

  s_mics->PdmRx.Init(pdm_res->p_pdm_mics, pdm_rx_config);

  if(channel_map) {
      s_mics->PdmRx.MapChannels(channel_map);
  }

  int divide = pdm_res->mclk_freq / pdm_res->pdm_freq;
  mic_array_resources_configure(pdm_res, divide);
  mic_array_pdm_clock_start(pdm_res);
}

void init_mic_array_storage(bool use_3_stg_decimator)
{
  assert(s_mics == nullptr && s_mics_3stg == nullptr); // Mic array instance already initialised

  s_use_3_stg_decimator = use_3_stg_decimator;
  if(s_use_3_stg_decimator) {
    static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(TMicArray_3stg_decimator)];
    s_mics_3stg = new (mic_storage) TMicArray_3stg_decimator();
  } else {
    static uint8_t __attribute__((aligned(8))) mic_storage[sizeof(TMicArray)];
     s_mics = new (mic_storage) TMicArray();
  }
}

template <typename TMics>
static inline void init_from_conf(TMics*& mics_ptr, pdm_rx_resources_t* pdm_res, mic_array_conf_t* conf)
{
  mics_ptr->Decimator.Init(conf->decimator_conf);
  mics_ptr->PdmRx.Init(pdm_res->p_pdm_mics, conf->pdmrx_conf);
  if (conf->pdmrx_conf.channel_map) {
    mics_ptr->PdmRx.MapChannels(conf->pdmrx_conf.channel_map);
  }
  mics_ptr->PdmRx.AssertOnDroppedBlock(false);
}

void init_mics_custom_filter(pdm_rx_resources_t* pdm_res, mic_array_conf_t* mic_array_conf)
{
  if(mic_array_conf->decimator_conf.num_filter_stages == 2) {
    init_from_conf<TMicArray>(s_mics, pdm_res, mic_array_conf);
  } else if(mic_array_conf->decimator_conf.num_filter_stages == 3) {
    init_from_conf<TMicArray_3stg_decimator>(s_mics_3stg, pdm_res, mic_array_conf);
  } else {
    assert(false && "Unsupported number of filter stages in mic_array_conf");
  }
}


/////////////////////
// Mic array start //
/////////////////////
void set_output_channel(chanend_t c_frames_out)
{
  if (s_use_3_stg_decimator) {
    assert(s_mics_3stg != nullptr);
    s_mics_3stg->OutputHandler.FrameTx.SetChannel(c_frames_out);
  } else {
    assert(s_mics != nullptr);
    s_mics->OutputHandler.FrameTx.SetChannel(c_frames_out);
  }
}

void shutdown_mic_array(void)
{
  if (s_use_3_stg_decimator) {
    s_mics_3stg->~TMicArray_3stg_decimator();
  }
  else {
    s_mics->~TMicArray();
  }

  s_mics_3stg = nullptr;
  s_mics = nullptr;
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
  assert(mics_ptr != nullptr);

  #if defined(__XS3A__)
  CLEAR_KEDI(); // Disable dual-issue mode on XS3A processors.  VX4 processors do not have a dual-issue mode.
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
  if (s_use_3_stg_decimator) {
    start_mics_with_pdm_isr<TMicArray_3stg_decimator>(s_mics_3stg, c_frames_out);
  }
  else {
    start_mics_with_pdm_isr<TMicArray>(s_mics, c_frames_out);
  }
#endif
}

// Helper functions for starting separate tasks
void start_pdm_task(void)
{
  s_mics->PdmRx.ThreadEntry();
}

void start_decimator_task(void)
{
  s_mics->ThreadEntry();
}

void start_pdm_task_3stg(void)
{
  s_mics_3stg->PdmRx.ThreadEntry();
}

void start_decimator_task_3stg(void)
{
  s_mics_3stg->ThreadEntry();
}

// Override pdm data port. Only used in tests where a chanend is used as a 'port' for input pdm data.
void _mic_array_override_pdm_port(chanend_t c_pdm)
{
  if (s_use_3_stg_decimator) {
    assert(s_mics_3stg != nullptr);
    s_mics_3stg->PdmRx.SetPort((port_t)c_pdm);
  } else {
    assert(s_mics != nullptr);
    s_mics->PdmRx.SetPort((port_t)c_pdm);
  }
}

// C wrapper
MA_C_API
void _mic_array_override_pdm_port_c(chanend_t c_pdm)
{
  _mic_array_override_pdm_port(c_pdm);
}

#endif // __XS3A__ || __VX4B__
