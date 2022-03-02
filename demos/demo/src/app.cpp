
#include <iostream>
#include <cstdio>
#include <xcore/channel_streaming.h>

#include "app.h"

#include "mic_array/cpp/MicArray.hpp"
#include "mic_array/cpp/Prefab.hpp"
#include "mic_array/etc/filters_default.h"


#define DCOE_ENABLED    true

using TMicArray = mic_array::prefab::BasicMicArray<N_MICS, 
                                                   SAMPLES_PER_FRAME, 
                                                   DCOE_ENABLED>;

TMicArray mics = TMicArray();


extern "C"
void app_init(
    port_t p_pdm_mics,
    streaming_channel_t c_pdm_blocks,
    chanend_t c_frames_out)
{
  mics.PdmRx.Init(p_pdm_mics, c_pdm_blocks);
  mics.OutputHandler.FrameTx.SetChannel(c_frames_out);
}

extern "C"
void app_pdm_rx_task()
{
  mics.PdmRx.ThreadEntry();
}

extern "C"
void app_decimator_task()
{
#if APP_USE_PDM_RX_ISR
  mics.PdmRx.InstallISR();
  mics.PdmRx.UnmaskISR();
#endif
  mics.ThreadEntry();
}


