#pragma once

#include "xs3_math.h"

#include "xcore_compat.h"

#include "mic_array_framing.h"

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
    chanend_t c_pdm_data;
    uint32_t* filter_coef;
    uint32_t* pdm_history;
  } stage1;

  struct {
    unsigned decimation_factor;
    xs3_filter_fir_s32_t* filters;
  } stage2;

  ma_framing_context_t* framing;

} ma_pdm_filter_context_t;


/**
 * This task receives PDM samples over a channel (a buffer pointer is passed) and
 * processes the PDM stream, turning it into a PCM stream using a two stage 
 * decimation filter.
 */
void ma_pdm_filter_task( 
    ma_pdm_filter_context_t* filter_context,
    void* app_context);


#ifdef __XC__
}
#endif //__XC__