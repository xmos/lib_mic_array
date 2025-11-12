// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#include <stdint.h>
#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

using TMicArray_stg2df_6 = mic_array::MicArray<MIC_ARRAY_CONFIG_MIC_COUNT,
                          mic_array::TwoStageDecimator<MIC_ARRAY_CONFIG_MIC_COUNT,
                                                       6,
                                                       STAGE2_TAP_COUNT>,
                          mic_array::StandardPdmRxService<MIC_ARRAY_CONFIG_MIC_IN_COUNT,
                                                          MIC_ARRAY_CONFIG_MIC_COUNT,
                                                          6>,
                          // std::conditional uses USE_DCOE to determine which
                          // sample filter is used.
                          typename std::conditional<MIC_ARRAY_CONFIG_USE_DC_ELIMINATION,
                                              mic_array::DcoeSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>,
                                              mic_array::NopSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>>::type,
                          mic_array::FrameOutputHandler<MIC_ARRAY_CONFIG_MIC_COUNT,
                                                        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                                        mic_array::ChannelFrameTransmitter>>;

using TMicArray_stg2df_3 = mic_array::MicArray<MIC_ARRAY_CONFIG_MIC_COUNT,
                          mic_array::TwoStageDecimator<MIC_ARRAY_CONFIG_MIC_COUNT,
                                                       3,
                                                       MIC_ARRAY_32K_STAGE_2_TAP_COUNT>,
                          mic_array::StandardPdmRxService<MIC_ARRAY_CONFIG_MIC_IN_COUNT,
                                                          MIC_ARRAY_CONFIG_MIC_COUNT,
                                                          3>,
                          // std::conditional uses USE_DCOE to determine which
                          // sample filter is used.
                          typename std::conditional<MIC_ARRAY_CONFIG_USE_DC_ELIMINATION,
                                              mic_array::DcoeSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>,
                                              mic_array::NopSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>>::type,
                          mic_array::FrameOutputHandler<MIC_ARRAY_CONFIG_MIC_COUNT,
                                                        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                                        mic_array::ChannelFrameTransmitter>>;

using TMicArray_stg2df_2 = mic_array::MicArray<MIC_ARRAY_CONFIG_MIC_COUNT,
                          mic_array::TwoStageDecimator<MIC_ARRAY_CONFIG_MIC_COUNT,
                                                       2,
                                                       MIC_ARRAY_48K_STAGE_2_TAP_COUNT>,
                          mic_array::StandardPdmRxService<MIC_ARRAY_CONFIG_MIC_IN_COUNT,
                                                          MIC_ARRAY_CONFIG_MIC_COUNT,
                                                          2>,
                          // std::conditional uses USE_DCOE to determine which
                          // sample filter is used.
                          typename std::conditional<MIC_ARRAY_CONFIG_USE_DC_ELIMINATION,
                                              mic_array::DcoeSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>,
                                              mic_array::NopSampleFilter<MIC_ARRAY_CONFIG_MIC_COUNT>>::type,
                          mic_array::FrameOutputHandler<MIC_ARRAY_CONFIG_MIC_COUNT,
                                                        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                                        mic_array::ChannelFrameTransmitter>>;

union UAnyMicArray {
    TMicArray_stg2df_6 m6;
    TMicArray_stg2df_3 m3;
    TMicArray_stg2df_2 m2;
};

enum MicArrayKind { NONE, DF_6, DF_3, DF_2 };
extern MicArrayKind g_kind;

extern TMicArray_stg2df_6* g_mics_df_6;
extern TMicArray_stg2df_3* g_mics_df_3;
extern TMicArray_stg2df_2* g_mics_df_2;


inline const uint32_t* stage_1_filter(unsigned stg2_dec_factor) {
  // stg2 decimation factor also seems to affect the stage1 filter used
  return (stg2_dec_factor == 2) ? &stage1_48k_coefs[0] : ((stg2_dec_factor == 3) ? &stage1_32k_coefs[0] : &stage1_coef[0]);
}
inline const int32_t* stage_2_filter(unsigned stg2_dec_factor) {
    return (stg2_dec_factor == 2) ? &stage2_48k_coefs[0] : ((stg2_dec_factor == 3) ? &stage2_32k_coefs[0] : &stage2_coef[0]);
}
inline const right_shift_t* stage_2_shift(unsigned stg2_dec_factor) {
    return (stg2_dec_factor == 2) ? &stage2_48k_shift : ((stg2_dec_factor == 3) ? &stage2_32k_shift : &stage2_shr);
}

template <typename TMicArrayType>
inline void init_mics(TMicArrayType* m, pdm_rx_resources_t* pdm_res, const unsigned* channel_map, unsigned stg2_dec_factor) {
  m->Decimator.Init(stage_1_filter(stg2_dec_factor), stage_2_filter(stg2_dec_factor), *stage_2_shift(stg2_dec_factor));
  m->PdmRx.Init(pdm_res->p_pdm_mics);
  if(channel_map) {
      m->PdmRx.MapChannels(channel_map);
  }
  int divide = pdm_res->mclk_freq / pdm_res->pdm_freq;
  mic_array_resources_configure(pdm_res, divide);
  mic_array_pdm_clock_start(pdm_res);
}

#define CLRSR(c)                asm volatile("clrsr %0" : : "n"(c));
#define CLEAR_KEDI()            CLRSR(XS1_SR_KEDI_MASK)

template <typename TMicArrayType>
inline void start_mics_with_pdm_isr(TMicArrayType* m, chanend_t c_frame_output) {
  //clear KEDI since pdm_rx_isr assumes single issue and the module is compiled with dual issue.
  CLEAR_KEDI()

  m->OutputHandler.FrameTx.SetChannel(c_frame_output);
  // Setup the ISR and enable. Then start decimator.
  m->PdmRx.AssertOnDroppedBlock(false);
  m->PdmRx.InstallISR();
  m->PdmRx.UnmaskISR();
  m->ThreadEntry();
}

template<typename TMicArrayType>
inline void create_mics_helper(uint32_t* storage, TMicArrayType*& ptr, pdm_rx_resources_t* res, const unsigned* map, unsigned stg2_dec_factor, int kind_value) {
    new (storage) TMicArrayType;
    ptr = reinterpret_cast<TMicArrayType*>(storage);
    g_kind = static_cast<decltype(g_kind)>(kind_value);
    init_mics(ptr, res, map, stg2_dec_factor);
}

template<typename TMicArrayType>
inline void shutdown_mics_helper(TMicArrayType*& ptr)
{
  ptr->~TMicArrayType();
  ptr = nullptr;
}
