
#include "mic_array_pdm_rx.h"
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



/**
 * If for whatever reason using a strong symbol isn't overriding ma_proc_sample(), 
 * this can be set to 1 to suppress the library definition.
 */
#ifndef MA_CONFIG_SUPPRESS_PROC_SAMPLE
#define MA_CONFIG_SUPPRESS_PROC_SAMPLE 0
#endif

#if !(MA_CONFIG_SUPPRESS_PROC_SAMPLE)
__attribute__((weak))
void ma_proc_sample(
    ma_decimator_context_t* config,
    void* app_context,
    int32_t pcm_sample[]) 
{
  if(config->dc_elim != NULL){
    ma_dc_elimination_next_sample(pcm_sample, config->dc_elim, pcm_sample, config->mic_count);
  }

  if(config->framing != NULL){
    ma_framing_add_sample(config->framing, app_context, pcm_sample);
  }
}
#endif


static inline void deinterleave_pdm_samples(
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

/**
 * Move buff[0:7] to buff[1:8]. Don't care what ends up in buff[0]
 */
static inline void shift_buffer(uint32_t* buff)
{
  uint32_t* src = &buff[-1];
  asm volatile("vldd %0[0]; vstd %1[0];" :: "r"(src), "r"(buff) : "memory" );
}




// NOTE: When the ISR triggers, it will immediately issue an  `extsp 4` instruction, decrementing the
//       stack pointer by 4 words (this is how it avoids clobbering registers). That means this 
//       function needs 4 more words of stack space than the compiler will decide it needs.
//      Unfortunately, I know of no way to force the compiler to automatically set the symbol 
//      mic_array_proc_pdm.maxstackwords to 4 more than it would otherwise. So for right now I am
//      just overriding mic_array_proc_pdm.maxstackwords to a constant much larger than it should
//      ever need.
#pragma stackfunction 400
void ma_decimator_task( 
    ma_decimator_context_t* config,
    chanend_t c_pdm_data,
    void* app_context)
{

  // The first stage decimator applies a 256-tap FIR filter for each channel, so we need
  // a history of 256 PDM samples (8 words) for each microphone. 
  // pdm_history is where we keep that filter stage. Its shape is (MIC_COUNT, 8 words)
  uint32_t* pdm_history = config->stage1.pdm_history;

  // Initializing the filter state to 0x55's hopefully minimizes start-up transients on the filter
  memset(pdm_history, 0x55, config->mic_count * 8 * sizeof(uint32_t));

  // A pointer to the array of second stage filters. Shape is (MIC_COUNT)
  xs3_filter_fir_s32_t* s2_filters = config->stage2.filters;

  // samples_out will be passed to ma_proc_sample_user(). The first MIC_COUNT elements of it will be
  // the next output samples from the second stage decimators.
  int32_t samples_out[MAX_MIC_COUNT] = {0};

  while(1) {

    ////// Wait for the next batch of PDM samples from the ISR.
    // This will deliver enough PDM samples to do a first AND second stage filter
    // for each microphone channel. (Note: All we're pulling out of the channel itself 
    // is a pointer to the PDM buffer.
    uint32_t* pdm_samples = ma_pdm_rx_buffer_receive(c_pdm_data);

    ////// De-interleave the channels in the received PDM buffer.
    // Because of the way multi-bit buffered ports work, each word pulled from the port in the ISR
    // will contain (32/MIC_COUNT) PDM samples for each microphone. In order to update each 
    // channel's history (first stage filter state) we need to consolidate the samples for each
    // mic into a single word. This function does that in-place.
    // The input to this function are the raw words pulled from the port in reverse order (i.e.
    // the oldest samples are at the highest index).
    // Note that because we've collected enough samples to do a new *second* stage output, we
    // have STAGE2_DEC_FACTOR *words* for *each* microphone in this buffer. Once pdm_samples
    // is boggled by this function, then pdm_samples can be treated as:
    //     uint32_t pdm_samples[STAGE2_DEC_FACTOR][MIC_COUNT]
    // with the first axis in reverse time order (pdm_samples[0][:] has the *newest* samples)
    deinterleave_pdm_samples(pdm_samples, config->mic_count, config->stage2.decimation_factor);

    ////// Iterate over microphones, producing one second stage output for each.
    // For each one we'll run the first stage decimator STAGE2_DEC_FACTOR times, and the
    // second stage decimator will be run once. The results go into samples_out[]
    for(unsigned mic = 0; mic < config->mic_count; mic++) {
      for(unsigned k = 0; k < config->stage2.decimation_factor; k++) {

        ////// Compute next streamA sample for this microphone
        int idx = (config->stage2.decimation_factor - 1 - k) * config->mic_count + mic;
        pdm_history[8*mic] = pdm_samples[idx];
        int32_t streamA_sample = fir_1x16_bit(&pdm_history[8*mic], config->stage1.filter_coef);

        ////// Rotate the PDM history vector
        // This shifts the first 7 words of the history vector up by a word, clobbering
        // whatever was in the 8th word (which isn't needed anymore).
        shift_buffer(&pdm_history[8*mic]);

        
        // // Doing DC offset elmination here uses STAGE2_DEC_FACTOR times the MIPS of doing
        // // it after the second stage decimation.
        // if(config->dc_elim != NULL){
        //   ma_dc_elimination_next_sample(&streamA_sample, &config->dc_elim[mic], 
        //                                 &streamA_sample, 1);
        // }

        // Up until the last iteration of k we're just adding the sample to our stage2 FIR.
        // On the last iteration we'll actually produce a new output sample.
        if(k < (config->stage2.decimation_factor-1)){
          xs3_filter_fir_s32_add_sample(&s2_filters[mic], streamA_sample);
        } else { 
          samples_out[mic] = xs3_filter_fir_s32(&s2_filters[mic], streamA_sample);
        }
      }
    }

    // Once we're done with all that, we just need to call proc_pcm_user()
    ma_proc_sample(config, 
                   app_context, 
                   samples_out);

  }
}





// void ma_stage2_filters_init(
//     xs3_filter_fir_s32_t filters[],
//     int32_t state_buffers[],
//     const unsigned mic_count,
//     const unsigned stage2_tap_count,
//     const int32_t* stage2_coef,
//     const right_shift_t stage2_shr)
// {
//   for(int k = 0; k < mic_count; k++){
//     xs3_filter_fir_s32_init(&filters[k],
//                             &state_buffers[k*stage2_tap_count],
//                             stage2_tap_count,
//                             stage2_coef,
//                             stage2_shr);
//   }
// }