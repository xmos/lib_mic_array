

#include <platform.h>

#include "app_config.h"
#include "app.h"
#include "i2s.h"
#include "util/audio_buffer.h"
#include "mic_array/framing.h"
#include "mic_array/frame_transfer.h"
#include "mic_array/etc/filters_default.h"

#include <xcore/interrupt.h>

#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <math.h>


static app_mic_array_data_t ma_data;
static ma_decimator_context_t decimator_context;

#if !(APP_USE_PDM_RX_ISR)
static pdm_rx_context_t pdm_rx_ctx;
#endif

void app_context_init(
    port_t p_pdm_mics,
    chanend_t c_pdm_data)
{
  // This has to be in C because ma_decimator_context_setup() is a macro rather than a function,
  //  and it does stuff with pointers that XC wouldn't like.
  ma_decimator_context_setup( &decimator_context, &ma_data, N_MICS,
                          stage1_coef, STAGE2_DEC_FACTOR,
                          STAGE2_TAP_COUNT, stage2_coef, stage2_shr, 
                          SAMPLES_PER_FRAME, 1);

#if !(APP_USE_PDM_RX_ISR)
  pdm_rx_ctx = pdm_rx_context((uint32_t*) &ma_data.stage1.pdm_buffers[0],
                              (uint32_t*) &ma_data.stage1.pdm_buffers[1],
                              N_MICS * STAGE2_DEC_FACTOR);
#endif
}


#if !(APP_USE_PDM_RX_ISR)
void app_pdm_rx_task(
    port_t p_pdm_mics,
    chanend_t c_pdm_data)
{
  pdm_rx_task(p_pdm_mics, pdm_rx_ctx, c_pdm_data);
}
#endif

void app_decimator_task(
    port_t p_pdm_mics,
    streaming_channel_t c_pdm_data,
    chanend_t c_decimator_out)
{
#if APP_USE_PDM_RX_ISR
  pdm_rx_isr_enable((port_t) p_pdm_mics, 
                       (uint32_t*) &ma_data.stage1.pdm_buffers[0],
                       (uint32_t*) &ma_data.stage1.pdm_buffers[1],
                       N_MICS * STAGE2_DEC_FACTOR,
                       c_pdm_data.end_a);

  // Once we unmask interrupts, the ISR will begin triggering and collecting PDM samples. At
  // that point we need to be ready to pull PDM samples from the ISR via the c_pdm_data chanend.
  interrupt_unmask_all();
#endif

  ma_decimator_task( &decimator_context, 
                     c_pdm_data.end_b, 
                     c_decimator_out );
}


