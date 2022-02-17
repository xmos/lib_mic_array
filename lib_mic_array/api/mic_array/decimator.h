#pragma once

#include "xs3_math.h"

#include "xcore_compat.h"

#include "mic_array/framing.h"
#include "mic_array/misc.h"

#include <stdint.h>

#ifdef __XC__
extern "C" {
#endif //__XC__


#define MA_PDM_HISTORY_SIZE_WORDS(MIC_COUNT)  ( 8*(MIC_COUNT) )



/**
 * This struct contains the configuration info needed by the mic array
 * filtering task.
 */
typedef struct {

  unsigned mic_count;

  struct {
    uint32_t* filter_coef;
    uint32_t* pdm_history;
  } stage1;

  struct {
    unsigned decimation_factor;
    xs3_filter_fir_s32_t* filters;
  } stage2;

  ma_framing_context_t* framing;
  ma_dc_elim_chan_state_t* dc_elim;

} ma_decimator_context_t;



/**
 * This task receives PDM samples over a channel (a buffer pointer is passed) and
 * processes the PDM stream, turning it into a PCM stream using a two stage 
 * decimation filter.
 */
void ma_decimator_task( 
    ma_decimator_context_t* filter_context,
    chanend_t c_pdm_data,
    ma_dec_output_t c_decimator_out);


#ifdef __XC__
}
#endif //__XC__