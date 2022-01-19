
#include "pdm_rx.h"
#include "mic_array.h"

#include "xs3_math.h"

#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <xcore/interrupt.h>

#define N_MICS                   (1)

unsigned pcm_sample_count = 0;

int32_t sample_buffer[N_MICS][STAGE2_TAP_COUNT] = {{0}};


xs3_filter_fir_s32_t decimation_filter[N_MICS];


void proc_pcm_init()
{

  for(int k = 0; k < N_MICS; k++){
    xs3_filter_fir_s32_init(&decimation_filter[k], 
                            &sample_buffer[k][0], 
                            STAGE2_TAP_COUNT, 
                            stage2_coef, 
                            STAGE2_SHR);
  }
  
}




__attribute__((weak))
void proc_pcm_user(int32_t pcm_frame[])
{
  // Do nothing...
}


void proc_pcm(int32_t* pcm_samples)
{

  // This quickly frees up the pcm_samples buffer.
  int32_t input_samples[N_MICS][STAGE2_DEC_FACTOR];
  memcpy(input_samples, pcm_samples, sizeof(input_samples));

  pcm_sample_count++;

  int32_t output_samps[N_MICS];

  if(STAGE2_DEC_FACTOR == 1){
    memcpy(output_samps, pcm_samples, sizeof(output_samps));
  } else {
    for(int mic = 0; mic < N_MICS; mic++){

      for(int s = 0; s < STAGE2_DEC_FACTOR-1; s++) 
        xs3_filter_fir_s32_add_sample(&decimation_filter[mic], input_samples[mic][s]);
      
      output_samps[mic] = xs3_filter_fir_s32(&decimation_filter[mic], 
                                          input_samples[mic][STAGE2_DEC_FACTOR-1]);
    }
  }

  proc_pcm_user(output_samps);
}