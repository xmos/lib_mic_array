#pragma once

#include "xs3_math.h"

#include <stdint.h>

#ifdef __XC__
extern "C" {
#endif //__XC__


#define MA_PDM_BUFFER_SIZE_WORDS(MIC_COUNT, S2_DEC_FACTOR)  ((2*(MIC_COUNT)*(S2_DEC_FACTOR))+(8*(MIC_COUNT)))


typedef struct {

  unsigned mic_count;

  struct {
    unsigned p_pdm_mics;
    uint32_t* filter_coef;
    uint32_t* pdm_buffers;
  } stage1;

  struct {
    unsigned decimation_factor;
    xs3_filter_fir_s32_t* filters;
  } stage2;

} pdm_rx_config_t;



void mic_array_pdm_rx_setup(
    pdm_rx_config_t* config);

void mic_array_proc_pdm( 
    pdm_rx_config_t* config );


#ifdef __XC__
}
#endif //__XC__