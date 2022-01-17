
#include "pdm_rx.h"
#include "mic_array.h"

#include "xs3_math.h"

#include <stdint.h>
#include <assert.h>
#include <stdio.h>

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
  
  int32_t (*input_samples)[STAGE2_DEC_FACTOR] = 
    (void*) pcm_samples;

  pcm_sample_count++;

  int32_t output_samps[N_MICS];

  // // REMOVE ME
  // for(int k = 0; k < 1; k++){
  //   unsigned zeros = 0;
  //   for(int s = 1; s < STAGE2_DEC_FACTOR; s++){
  //     zeros += (input_samples[k][s] == 0);
  //   }
  //   // printf("Zeros: %d\n", zeros);
  //   if(pcm_sample_count >= 1000 && zeros >= 5){
  //     interrupt_mask_all();

  //     printf("Mic: %d\n", k);
  //     printf("Samps: %u\n", pcm_sample_count);
  //     for(int s = 0; s < STAGE2_DEC_FACTOR; s++)
  //       printf("%ld, ", input_samples[k][s]);
  //     printf("\n");
  //     delay_milliseconds(1);
  //     assert(zeros < 5);
  //   }
  // }
  // // REMOVE ME

  for(int k = 0; k < N_MICS; k++){

    for(int s = 0; s < STAGE2_DEC_FACTOR-1; s++) {
      xs3_filter_fir_s32_add_sample(&decimation_filter[k], input_samples[k][s]);
    }
    
    output_samps[k] = xs3_filter_fir_s32(&decimation_filter[k], 
                                         input_samples[k][STAGE2_DEC_FACTOR-1]);
  }

  proc_pcm_user(output_samps);
}