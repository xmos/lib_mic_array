
#include "pdm_rx.h"
#include "mic_array.h"
#include "fir_1x16_bit.h"

#include "xs3_math.h"

#include <xcore/port.h>
// #include <xcore/channel.h>
#include <xcore/channel_streaming.h>
#include <xcore/hwtimer.h>
#include <xcore/interrupt.h>

#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>



#define N_MICS              2
#define STAGE2_DEC_FACTOR   6


extern struct {
  port_t p_pdm_data;
  chanend_t c_pdm_out;
  uint32_t* buffA;
  uint32_t* buffB;
  unsigned phase1;
  unsigned phase1_reset;
  chanend_t c_pdm_in;
} pdm_rx_context;


static int32_t sample_buffer[N_MICS][STAGE2_TAP_COUNT] = {{0}};
static xs3_filter_fir_s32_t decimation_filter[N_MICS];





void deinterleave_pdm_samples(
    uint32_t* samples,
    const unsigned n_mics, 
    const unsigned stage2_dec_factor)
{
  // unsigned offset = 0;

  switch(n_mics){
    case 1:
      break;
    case 2:
      for(int k = 0; k < stage2_dec_factor; k++){
        asm volatile(
          "ldw r0, %0[1]      \n"
          "ldw r1, %0[0]      \n"
          "unzip r1, r0, 0    \n"
          "stw r0, %0[0]      \n"
          "stw r1, %0[1]        " :: "r"(samples) : "r0", "r1", "memory" );
        samples += 2;
      }
      break;
    default:
      assert(0); // TODO: not yet implemented
  }
}

static inline void rotate_buffer(uint32_t* buff)
{
  asm volatile("ldc r11, 0; vsetc r11;" ::: "r11");
  asm volatile("vldd %0[0]; vlmaccr %0[0]; vstd %0[0]" :: "r"(buff));
}




__attribute__((weak))
void proc_pcm_user(int32_t pcm_frame[])
{
  // Do nothing...
}



void mic_array_pdm_rx_setup(
    pdm_rx_config_t* config)
{

  streaming_channel_t c_pdm = s_chan_alloc();
  assert(c_pdm.end_a != 0 && c_pdm.end_b != 0);

  // 32-bits per 96k PCM sample per microphone
  // and stage2_dec_factor 96k PCM samples per pipeline sample
  unsigned buffA_size_words = config->mic_count * config->stage2_decimation_factor;

  pdm_rx_context.p_pdm_data = config->p_pdm_mics;
  pdm_rx_context.c_pdm_out = c_pdm.end_a;
  pdm_rx_context.buffA = &config->pdm_buffer[0];
  pdm_rx_context.buffB = &config->pdm_buffer[buffA_size_words];
  pdm_rx_context.phase1_reset = buffA_size_words - 1;
  pdm_rx_context.phase1 = pdm_rx_context.phase1_reset;
  pdm_rx_context.c_pdm_in = c_pdm.end_b;

  asm volatile(
      "setc res[%0], %1       \n"
      "ldap r11, pdm_rx_isr   \n"
      "setv res[%0], r11      \n"
      "eeu res[%0]              "
        :
        : "r"(config->p_pdm_mics), "r"(XS1_SETC_IE_MODE_INTERRUPT)
        : "r11" );

  // Note that this does not unmask interrupts on this core

  for(int k = 0; k < config->mic_count; k++){
    xs3_filter_fir_s32_init(&decimation_filter[k],
                            &sample_buffer[k][0],
                            STAGE2_TAP_COUNT,
                            config->stage2_coef,
                            STAGE2_SHR);
  }
}





/*
  In the comments within this function, for the sake of clarity I will refer to the samples as the:
  - PDM stream -- the PDM samples which are the input to the stage1 decimator
  - stream A -- the 32-bit PCM samples which are the output of the stage1 decimator and input to the stage2 decimator
  - stream B -- the 32-bit PCM samples which are the output of the stage2 decimator

*/
#pragma stackfunction 400
void mic_array_proc_pdm( 
    pdm_rx_config_t* config )
{

  mic_array_pdm_rx_setup( config );

  uint32_t pdm_history[N_MICS][8];
  memset(pdm_history, 0x55, sizeof(pdm_history));

  interrupt_unmask_all();


  while(1) {

    // Wait for the next batch of PDM samples from the ISR
    uint32_t* pdm_samples = (uint32_t*) s_chan_in_word(pdm_rx_context.c_pdm_in);

    // The first stage decimator has a tap count of 256, and we're getting 32 samples per mic per 96k sample
    // So we'll need to keep a history of previous values here.

    // For the next step, we're just going to de-interleave the PDM samples

    deinterleave_pdm_samples(pdm_samples, N_MICS, STAGE2_DEC_FACTOR);

    // pdm_samples now has the effective shape (STAGE2_DEC_FACTOR, N_MICS) with the first dimension being
    // in reverse order

    // Now we have 32*STAGE2_DEC_FACTOR words for each microphone. Now we can just iterate over microphones
    // and 96k samples to produce our output sample vector

    int32_t samples_out[N_MICS] = {12345};
    
    for(unsigned mic = 0; mic < config->mic_count; mic++) {
      for(unsigned k = 0; k < config->stage2_decimation_factor; k++) {

        // Compute next streamA sample for this microphone
        int idx = (config->stage2_decimation_factor - 1 - k) * config->mic_count + mic;
        pdm_history[mic][0] = pdm_samples[idx];
        int32_t streamA_sample = fir_1x16_bit(&pdm_history[mic][0], config->stage1_coef, 1);

        // Rotate the history vector
        rotate_buffer(&pdm_history[mic][0]);

        // Up until the last iteration of k we're just adding the sample to our stage2 FIR.
        // On the last iteration we'll actually produce a new output sample.
        if(k < (config->stage2_decimation_factor-1)){
          xs3_filter_fir_s32_add_sample(&decimation_filter[mic], streamA_sample);
        } else { 
          samples_out[mic] = xs3_filter_fir_s32(&decimation_filter[mic], streamA_sample);
        }
      }
    }

    // Once we're done with all that, we just need to call proc_pcm_user()
    proc_pcm_user(samples_out);
  }
}
