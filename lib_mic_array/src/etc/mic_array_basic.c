

#include "mic_array/etc/basic.h"

#if MIC_ARRAY_BASIC_API_ENABLE

#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

#include <stdint.h>
#include <xcore/channel_streaming.h>
#include <xcore/interrupt.h>


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

////// Additional correctness checks


////// Allocate needed objects

static MA_STATE_DATA(MIC_ARRAY_CONFIG_MIC_COUNT,
                      STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                      MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME, 
                      MIC_ARRAY_CONFIG_USE_DC_ELIMINATION) mic_array_data;

static ma_decimator_context_t decimator_context;



void ma_basic_init(
    pdm_rx_resources_t* pdm_res)
{
  ma_decimator_context_setup( &decimator_context, &mic_array_data,
                          MIC_ARRAY_CONFIG_MIC_COUNT,
                          stage1_coef, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                          stage2_coef, stage2_shr, 
                          MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME, 
                          MIC_ARRAY_CONFIG_USE_DC_ELIMINATION);

  mic_array_setup(pdm_res, MIC_ARRAY_CONFIG_MCLK_DIVIDER);
  mic_array_start(pdm_res);
}


void ma_basic_task(
    pdm_rx_resources_t* pdm_res,
    chanend_t c_frames_out)
{
  streaming_channel_t c_pdm_data = s_chan_alloc();
  assert(c_pdm_data.end_a != 0 && c_pdm_data.end_b != 0);

  pdm_rx_isr_enable(pdm_res->p_pdm_mics,
                    (uint32_t*) &mic_array_data.stage1.pdm_buffers[0],        
                    (uint32_t*) &mic_array_data.stage1.pdm_buffers[1],
                    MIC_ARRAY_CONFIG_MIC_COUNT * STAGE2_DEC_FACTOR,
                    c_pdm_data.end_a);

  interrupt_unmask_all();

  ma_decimator_task( &decimator_context, 
                     c_pdm_data.end_b, 
                     c_frames_out );
}


#endif // MIC_ARRAY_BASIC_API_ENABLE
