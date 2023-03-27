// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app.h"

#include "mic_array/cpp/Prefab.hpp"

#define APP_AUDIO_CLOCK_FREQUENCY   24576000
#define APP_PDM_CLOCK_FREQUENCY      3072000

pdm_rx_resources_t pdm_res_sdr = 
    PDM_RX_RESOURCES_SDR(
      PORT_MCLK_IN_OUT,
      PORT_PDM_CLK,
      PORT_PDM_DATA,
      XS1_CLKBLK_1);

pdm_rx_resources_t pdm_res_ddr = 
    PDM_RX_RESOURCES_DDR(
      PORT_MCLK_IN_OUT,
      PORT_PDM_CLK,
      PORT_PDM_DATA,
      XS1_CLKBLK_1,
      XS1_CLKBLK_2);

using namespace mic_array::prefab;


BasicMicArray<1, 1, false>    mics_1_1_false;
BasicMicArray<1, 1, true>     mics_1_1_true;
BasicMicArray<1, 16, false>   mics_1_16_false;
BasicMicArray<1, 16, true>    mics_1_16_true;
BasicMicArray<1, 256, false>  mics_1_256_false;
BasicMicArray<1, 256, true>   mics_1_256_true;

BasicMicArray<2, 1, false>    mics_2_1_false;
BasicMicArray<2, 1, true>     mics_2_1_true;
BasicMicArray<2, 16, false>   mics_2_16_false;
BasicMicArray<2, 16, true>    mics_2_16_true;
BasicMicArray<2, 256, false>  mics_2_256_false;
BasicMicArray<2, 256, true>   mics_2_256_true;




#define mics_call(ACTION) do {                      \
  if(mic_count == 1){                               \
    if(use_dcoe){                                   \
      if(frame_size == 1) {                         \
        mics_1_1_true.ACTION;                       \
      } else if(frame_size == 16) {                 \
        mics_1_16_true.ACTION;                      \
      } else {                                      \
        mics_1_256_true.ACTION;                     \
      }                                             \
    } else {                                        \
      if(frame_size == 1) {                         \
        mics_1_1_false.ACTION;                      \
      } else if(frame_size == 16) {                 \
        mics_1_16_false.ACTION;                     \
      } else {                                      \
        mics_1_256_false.ACTION;                    \
      }                                             \
    }                                               \
  } else {                                          \
    if(use_dcoe){                                   \
      if(frame_size == 1) {                         \
        mics_2_1_true.ACTION;                       \
      } else if(frame_size == 16) {                 \
        mics_2_16_true.ACTION;                      \
      } else {                                      \
        mics_2_256_true.ACTION;                     \
      }                                             \
    } else {                                        \
      if(frame_size == 1) {                         \
        mics_2_1_false.ACTION;                      \
      } else if(frame_size == 16) {                 \
        mics_2_16_false.ACTION;                     \
      } else {                                      \
        mics_2_256_false.ACTION;                    \
      }                                             \
    }                                               \
  } } while(0)




// The parameters of these functions prevents any of the
// `BasicMicArray` instances from being optimized out
MA_C_API
void app_init(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe)
{
  assert(mic_count == 1 || mic_count == 2);
  assert(frame_size == 1 || frame_size == 16 || frame_size == 256);
  
  const unsigned mclk_div = mic_array_mclk_divider(
      APP_AUDIO_CLOCK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY);

  
  mics_1_1_true.Init();
  mics_1_16_true.Init();
  mics_1_256_true.Init();
  mics_1_1_false.Init();
  mics_1_16_false.Init();
  mics_1_256_false.Init();

  mics_2_1_true.Init();
  mics_2_16_true.Init();
  mics_2_256_true.Init();
  mics_2_1_false.Init();
  mics_2_16_false.Init();
  mics_2_256_false.Init();

  // No harm in setting the port on all of them.
  mics_1_1_true.SetPort(pdm_res_sdr.p_pdm_mics);
  mics_1_16_true.SetPort(pdm_res_sdr.p_pdm_mics);
  mics_1_256_true.SetPort(pdm_res_sdr.p_pdm_mics);
  mics_1_1_false.SetPort(pdm_res_sdr.p_pdm_mics);
  mics_1_16_false.SetPort(pdm_res_sdr.p_pdm_mics);
  mics_1_256_false.SetPort(pdm_res_sdr.p_pdm_mics);

  mics_2_1_true.SetPort(pdm_res_ddr.p_pdm_mics);
  mics_2_16_true.SetPort(pdm_res_ddr.p_pdm_mics);
  mics_2_256_true.SetPort(pdm_res_ddr.p_pdm_mics);
  mics_2_1_false.SetPort(pdm_res_ddr.p_pdm_mics);
  mics_2_16_false.SetPort(pdm_res_ddr.p_pdm_mics);
  mics_2_256_false.SetPort(pdm_res_ddr.p_pdm_mics);
  
  if(mic_count == 1)
    mic_array_resources_configure(&pdm_res_sdr, mclk_div);
  else
    mic_array_resources_configure(&pdm_res_ddr, mclk_div);
}

// If pdm_rx is to be run as a thread
MA_C_API
void app_pdm_rx_task(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe)
{  
  assert(mic_count == 1 || mic_count == 2);
  assert(frame_size == 1 || frame_size == 16 || frame_size == 256);
  
  if(mic_count == 1) 
    mic_array_pdm_clock_start(&pdm_res_sdr);
  else 
    mic_array_pdm_clock_start(&pdm_res_ddr);
  
  mics_call(PdmRxThreadEntry());
}


MA_C_API
void app_setup_pdm_rx_isr(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe)
{  
  assert(mic_count == 1 || mic_count == 2);
  assert(frame_size == 1 || frame_size == 16 || frame_size == 256);

  if(mic_count == 1) 
    mic_array_pdm_clock_start(&pdm_res_sdr);
  else 
    mic_array_pdm_clock_start(&pdm_res_ddr);

  mics_call(InstallPdmRxISR());
  mics_call(UnmaskPdmRxISR());
}


MA_C_API
void app_decimator_task(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe,
    chanend_t c_audio_frames)
{  
  assert(mic_count == 1 || mic_count == 2);
  assert(frame_size == 1 || frame_size == 16 || frame_size == 256);

  // No harm in setting the channel on all of them.
  mics_1_1_true.SetOutputChannel(c_audio_frames);
  mics_1_16_true.SetOutputChannel(c_audio_frames);
  mics_1_256_true.SetOutputChannel(c_audio_frames);
  mics_1_1_false.SetOutputChannel(c_audio_frames);
  mics_1_16_false.SetOutputChannel(c_audio_frames);
  mics_1_256_false.SetOutputChannel(c_audio_frames);

  mics_2_1_true.SetOutputChannel(c_audio_frames);
  mics_2_16_true.SetOutputChannel(c_audio_frames);
  mics_2_256_true.SetOutputChannel(c_audio_frames);
  mics_2_1_false.SetOutputChannel(c_audio_frames);
  mics_2_16_false.SetOutputChannel(c_audio_frames);
  mics_2_256_false.SetOutputChannel(c_audio_frames);

  mics_call(ThreadEntry());
}