
#include <stdint.h>
#include <xcore/channel_streaming.h>
#include <xcore/interrupt.h>

#include "mic_array_vanilla.h"

#include "mic_array/cpp/Prefab.hpp"

#include "mic_array.h"
#include "mic_array/etc/filters_default.h"


////// Check that all the required config macros have been defined. 

#ifndef MIC_ARRAY_CONFIG_MCLK_FREQ
# error Application must specify the master clock frequency by defining MIC_ARRAY_CONFIG_MCLK_FREQ.
#endif

#ifndef MIC_ARRAY_CONFIG_PDM_FREQ
# error Application must specify the PDM clock frequency by defining MIC_ARRAY_CONFIG_PDM_FREQ.
#endif

#ifndef MIC_ARRAY_CONFIG_MIC_COUNT
# error Application must specify the microphone count by defining MIC_ARRAY_CONFIG_MIC_COUNT.
#endif


////// Provide default values for optional config macros

#ifndef MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME    
# define MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME    (1)
#else
# if ((MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME) < 1)
#  error MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME must be positive.
# endif
#endif

#ifndef MIC_ARRAY_CONFIG_USE_DC_ELIMINATION
# define MIC_ARRAY_CONFIG_USE_DC_ELIMINATION    (1)
#endif


////// Additional macros derived from others

#define MIC_ARRAY_CONFIG_MCLK_DIVIDER     ((MIC_ARRAY_CONFIG_MCLK_FREQ)/(MIC_ARRAY_CONFIG_PDM_FREQ))
#define MIC_ARRAY_CONFIG_OUT_SAMPLE_RATE    ((MIC_ARRAY_CONFIG_PDM_FREQ)/(STAGE2_DEC_FACTOR))

////// Any Additional correctness checks



////// Allocate needed objects

using TMicArray = mic_array::prefab::BasicMicArray<
                        MIC_ARRAY_CONFIG_MIC_COUNT,
                        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                        MIC_ARRAY_CONFIG_USE_DC_ELIMINATION>;

TMicArray mics;


void ma_vanilla_init(
    pdm_rx_resources_t* pdm_res)
{
  mics.PdmRx.SetPort(pdm_res->p_pdm_mics);
  mic_array_setup(pdm_res, MIC_ARRAY_CONFIG_MCLK_DIVIDER);
  mic_array_start(pdm_res);

}


void ma_vanilla_task(
    pdm_rx_resources_t* pdm_res,
    chanend_t c_frames_out)
{
  streaming_channel_t c_pdm_data = s_chan_alloc();
  assert(c_pdm_data.end_a != 0 && c_pdm_data.end_b != 0);

  mics.PdmRx.SetChannel(c_pdm_data);
  mics.OutputHandler.FrameTx.SetChannel(c_frames_out);

  mics.PdmRx.InstallISR();
  mics.PdmRx.UnmaskISR();

  mics.ThreadEntry();
}