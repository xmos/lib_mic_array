
#include "pdm_rx.h"
#include "mic_array.h"

#include "xs3_math.h"

#include <stdint.h>
#include <assert.h>
#include <stdio.h>

#define N_MICS                   (2)
#define STAGE2_DECIMATION_FACTOR (6)
#define STAGE2_FILTER_TAPS       (8)

unsigned pcm_sample_count = 0;

int32_t filter_coefs[STAGE2_FILTER_TAPS] = {0};
const right_shift_t filter_right_shift = 0;

int32_t sample_buffer[N_MICS][STAGE2_FILTER_TAPS] = {{0}};


xs3_filter_fir_s32_t decimation_filter[N_MICS];


void proc_pcm_init()
{
  for(int k = 0; k < N_MICS; k++){
    xs3_filter_fir_s32_init(&decimation_filter[k], 
                            &sample_buffer[k][0], 
                            STAGE2_FILTER_TAPS, 
                            filter_coefs, 
                            filter_right_shift);
  }
}

void proc_pcm(int32_t* pcm_samples)
{
  pcm_sample_count++;

  int32_t output_samps[N_MICS];

  for(int k = 0; k < N_MICS; k++){

    int32_t* samps = &pcm_samples[STAGE2_DECIMATION_FACTOR * k];

    for(int s = 0; s < STAGE2_DECIMATION_FACTOR-1; s++)
      xs3_filter_fir_s32_add_sample(&decimation_filter[k], samps[s]);
    
    output_samps[k] = xs3_filter_fir_s32(&decimation_filter[k], 
                                         samps[STAGE2_DECIMATION_FACTOR-1]);
  }

  // for now just to avoid unused variable warning
  assert(output_samps[0] != 541235347); 
    
}