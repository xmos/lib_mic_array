// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#include <stdint.h>
#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

using TMicArray =  mic_array::MicArray<MIC_ARRAY_CONFIG_MIC_COUNT,
                        mic_array::TwoStageDecimator<MIC_ARRAY_CONFIG_MIC_COUNT>,
                        mic_array::StandardPdmRxService<MIC_ARRAY_CONFIG_MIC_IN_COUNT,
                                                        MIC_ARRAY_CONFIG_MIC_COUNT>,
                        // std::conditional uses USE_DCOE to determine which
                        // sample filter is used.
                        typename std::conditional<MIC_ARRAY_CONFIG_USE_DC_ELIMINATION,
                                            mic_array::DcoeSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>,
                                            mic_array::NopSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>>::type,
                        mic_array::FrameOutputHandler<MIC_ARRAY_CONFIG_MIC_COUNT,
                                                      MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                                      mic_array::ChannelFrameTransmitter>>;


union UStg2_filter_state {
  int32_t filter_state_df_6[MIC_ARRAY_CONFIG_MIC_COUNT][STAGE2_TAP_COUNT];
  int32_t filter_state_df_3[MIC_ARRAY_CONFIG_MIC_COUNT][MIC_ARRAY_32K_STAGE_2_TAP_COUNT];
  int32_t filter_state_df_2[MIC_ARRAY_CONFIG_MIC_COUNT][MIC_ARRAY_48K_STAGE_2_TAP_COUNT];
};

union UPdmRx_out_block {
  uint32_t out_block_df_6[MIC_ARRAY_CONFIG_MIC_COUNT][6];
  uint32_t out_block_df_3[MIC_ARRAY_CONFIG_MIC_COUNT][3];
  uint32_t out_block_df_2[MIC_ARRAY_CONFIG_MIC_COUNT][2];
};

union UPdmRx_out_block_double_buf {
  uint32_t __attribute__((aligned (8))) out_block_double_buf_df_6[2][MIC_ARRAY_CONFIG_MIC_IN_COUNT * 6];
  uint32_t __attribute__((aligned (8))) out_block_double_buf_df_3[2][MIC_ARRAY_CONFIG_MIC_IN_COUNT * 3];
  uint32_t __attribute__((aligned (8))) out_block_double_buf_df_2[2][MIC_ARRAY_CONFIG_MIC_IN_COUNT * 2];
};


extern TMicArray* g_mics;

UStg2_filter_state stg2_filter_state_mem;
UPdmRx_out_block pdm_rx_out_block;
UPdmRx_out_block_double_buf __attribute__((aligned (8))) pdm_rx_out_block_double_buf;

inline const uint32_t* stage_1_filter(unsigned stg2_dec_factor) {
  // stg2 decimation factor also seems to affect the stage1 filter used
  return (stg2_dec_factor == 2) ? &stage1_48k_coefs[0] : ((stg2_dec_factor == 3) ? &stage1_32k_coefs[0] : &stage1_coef[0]);
}
inline const int32_t* stage_2_filter(unsigned stg2_dec_factor) {
    return (stg2_dec_factor == 2) ? &stage2_48k_coefs[0] : ((stg2_dec_factor == 3) ? &stage2_32k_coefs[0] : &stage2_coef[0]);
}
inline const right_shift_t stage_2_shift(unsigned stg2_dec_factor) {
    return (stg2_dec_factor == 2) ? stage2_48k_shift : ((stg2_dec_factor == 3) ? stage2_32k_shift : stage2_shr);
}
inline unsigned stage_2_num_taps(unsigned stg2_dec_factor) {
    return (stg2_dec_factor == 2) ? MIC_ARRAY_48K_STAGE_2_TAP_COUNT : ((stg2_dec_factor == 3) ? MIC_ARRAY_32K_STAGE_2_TAP_COUNT : STAGE2_TAP_COUNT);
}
inline int32_t* stage_2_state_memory(unsigned stg2_dec_factor) {
   return (stg2_dec_factor == 2) ? (int32_t*)stg2_filter_state_mem.filter_state_df_6 \
            : ((stg2_dec_factor == 3) ? (int32_t*)stg2_filter_state_mem.filter_state_df_3 \
            : (int32_t*)stg2_filter_state_mem.filter_state_df_2);
}

inline uint32_t* get_pdm_rx_out_block(unsigned stg2_dec_factor) {
   return (stg2_dec_factor == 2) ? (uint32_t*)pdm_rx_out_block.out_block_df_2 \
            : ((stg2_dec_factor == 3) ? (uint32_t*)pdm_rx_out_block.out_block_df_3 \
            : (uint32_t*)pdm_rx_out_block.out_block_df_6);
}

inline uint32_t* get_pdm_rx_out_block_double_buf(unsigned stg2_dec_factor) {
   return (stg2_dec_factor == 2) ? (uint32_t*)pdm_rx_out_block_double_buf.out_block_double_buf_df_6 \
            : ((stg2_dec_factor == 3) ? (uint32_t*)pdm_rx_out_block_double_buf.out_block_double_buf_df_3 \
            : (uint32_t*)pdm_rx_out_block_double_buf.out_block_double_buf_df_2);
}

template <typename TMicArrayType>
inline void init_mics(TMicArrayType* m, pdm_rx_resources_t* pdm_res, const unsigned* channel_map, unsigned stg2_dec_factor) {
  static int32_t stg1_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][8];
  mic_array_decimator_conf_t decimator_conf;
  memset(&decimator_conf, 0, sizeof(decimator_conf));
  decimator_conf.mic_count = MIC_ARRAY_CONFIG_MIC_COUNT;
  decimator_conf.filter_conf[0].coef = (int32_t*)stage_1_filter(stg2_dec_factor);
  decimator_conf.filter_conf[0].num_taps = 256;
  decimator_conf.filter_conf[0].decimation_factor = 32;
  decimator_conf.filter_conf[0].state = (int32_t*)stg1_filter_state;
  decimator_conf.filter_conf[0].state_size = 8;

  decimator_conf.filter_conf[1].coef = (int32_t*)stage_2_filter(stg2_dec_factor);
  decimator_conf.filter_conf[1].decimation_factor = stg2_dec_factor;
  decimator_conf.filter_conf[1].num_taps = stage_2_num_taps(stg2_dec_factor);
  decimator_conf.filter_conf[1].shr = stage_2_shift(stg2_dec_factor);
  decimator_conf.filter_conf[1].state_size = decimator_conf.filter_conf[1].num_taps;
  decimator_conf.filter_conf[1].state = stage_2_state_memory(stg2_dec_factor);

  m->Decimator.Init_new(decimator_conf);

  pdm_rx_config_t pdm_rx_config;
  pdm_rx_config.num_mics = MIC_ARRAY_CONFIG_MIC_COUNT;
  pdm_rx_config.num_mics_in = MIC_ARRAY_CONFIG_MIC_IN_COUNT;
  pdm_rx_config.out_block_size = stg2_dec_factor;
  pdm_rx_config.out_block = get_pdm_rx_out_block(stg2_dec_factor);
  pdm_rx_config.out_block_double_buf = get_pdm_rx_out_block_double_buf(stg2_dec_factor);

  m->PdmRx.Init_new(pdm_res->p_pdm_mics, pdm_rx_config);

  if(channel_map) {
      m->PdmRx.MapChannels(channel_map);
  }
  int divide = pdm_res->mclk_freq / pdm_res->pdm_freq;
  mic_array_resources_configure(pdm_res, divide);
  mic_array_pdm_clock_start(pdm_res);
}

#define CLRSR(c)                asm volatile("clrsr %0" : : "n"(c));
#define CLEAR_KEDI()            CLRSR(XS1_SR_KEDI_MASK)


inline void start_mics_with_pdm_isr(TMicArray* m, chanend_t c_frame_output) {
  //clear KEDI since pdm_rx_isr assumes single issue and the module is compiled with dual issue.
  CLEAR_KEDI()

  m->OutputHandler.FrameTx.SetChannel(c_frame_output);
  // Setup the ISR and enable. Then start decimator.
  m->PdmRx.AssertOnDroppedBlock(false);
  m->PdmRx.InstallISR();
  m->PdmRx.UnmaskISR();
  m->ThreadEntry();
}

inline void create_mics_helper(uint32_t* storage, TMicArray*& ptr, pdm_rx_resources_t* res, const unsigned* map, unsigned stg2_dec_factor) {
    new (storage) TMicArray;
    ptr = reinterpret_cast<TMicArray*>(storage);
    init_mics(ptr, res, map, stg2_dec_factor);
}

inline void shutdown_mics_helper(TMicArray*& ptr)
{
  ptr->~TMicArray();
  ptr = nullptr;
}
