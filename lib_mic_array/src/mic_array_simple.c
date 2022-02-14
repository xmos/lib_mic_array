

#ifndef MIC_ARRAY_SIMPLE_API_ENABLE
# define MIC_ARRAY_SIMPLE_API_ENABLE    (0)
#endif

#if MIC_ARRAY_SIMPLE_API_ENABLE

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


////// Additional macros derived from others

#define MIC_ARRAY_CONFIG_MCLK_DIVIDER     ((MIC_ARRAY_CONFIG_MCLK_FREQ)/(MIC_ARRAY_CONFIG_PDM_FREQ))

////// Additional correctness checks


////// Allocate needed objects

static MIC_ARRAY_DATA(MIC_ARRAY_CONFIG_MIC_COUNT,
                      STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                      MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME, 1) mic_array_data;

static ma_decimator_context_t decimator_context;



void mic_array_simple_init(
  pdm_rx_resources_t* pdm_res)
{
  mic_array_context_init( &decimator_context, &mic_array_data,
                          MIC_ARRAY_CONFIG_MIC_COUNT,
                          stage1_coef, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
                          stage2_coef, stage2_shr, 
                          MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                          MA_FMT_SAMPLE_CHANNEL, 1);

  mic_array_setup(pdm_res, MIC_ARRAY_CONFIG_MCLK_DIVIDER);
  mic_array_start(pdm_res);
}


void mic_array_simple_decimator_task(
  pdm_rx_resources_t* pdm_res,
  streaming_channel_t c_pdm_data)
{
  pdm_rx_isr_enable(pdm_res->p_pdm_mics,
                    (uint32_t*) &ma_data.stage1.pdm_buffers[0],        
                    (uint32_t*) &ma_data.stage1.pdm_buffers[1],
                    MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME * STAGE2_DEC_FACTOR,
                    c_pdm_data.end_a);

  interrupt_unmask_all();

  ma_decimator_task( &decimator_context, c_pdm_data.end_b, &app_context );
}


#endif // MIC_ARRAY_SIMPLE_API_ENABLE
