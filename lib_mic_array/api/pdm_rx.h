#pragma once

#include <stdint.h>


#ifdef __XC__
extern "C" {
#endif //__XC__


#define MA_PDM_BUFFER_SIZE_WORDS(MIC_COUNT, S2_DEC_FACTOR)  (2*(MIC_COUNT)*(S2_DEC_FACTOR))


typedef struct {

  unsigned mic_count;
  unsigned p_pdm_mics;

  uint32_t* stage1_coef;
  int32_t* stage2_coef;

  unsigned stage2_decimation_factor;

  uint32_t* pdm_buffer;

} pdm_rx_config_t;



void mic_array_pdm_rx_setup(
    pdm_rx_config_t* config);

void mic_array_proc_pdm( 
    pdm_rx_config_t* config );


#ifdef __XC__
}
#endif //__XC__