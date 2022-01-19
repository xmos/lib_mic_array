
#include "pdm_rx.h"
#include "mic_array.h"
#include "fir_1x16_bit.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>

#include <xcore/port.h>
#include <xcore/hwtimer.h>

#include <stdint.h>
#include <assert.h>
#include <stdio.h>

void proc_pcm(int32_t* pcm_samples);


unsigned proc_time = 0;

// astew: I asked ASJ and he said he doesn't think the first stage decimator will require more 
//        than one coefficient block, so this should be fine to shift PDM samples.
static inline void rotate_buffs(unsigned* buff, const unsigned mics)
{
  asm volatile("ldc r11, 0; vsetc r11;" ::: "r11");

  for(int c = 0; c < mics; c++){
    unsigned* b = &buff[8*c];
    asm volatile("vldd %0[0]; vlmaccr %0[0]; vstd %0[0]" :: "r"(b));
  }
}


/*
  astew: Okay, here's my idea for how a C implementation can split the work being done
  up, so that the heavy lifting with 8 microphones doesn't all have to come between
  just the last port input before decimation and the first port input for the next
  decimation.

  We'll use the counter `s` that increments below with each port read, and we'll create a
  big `switch` block that will choose the work being done based on the value of `s`. Then
  to balance the work for 8 mics we just need to move things between the various cases.

  However, for this to work we will need to add basically one full output PCM sample's
  worth of latency into the system. So normally, that will be 1/16kHz = 62.5 us.
  The reason for this extra latency is because it doesn't make sense for example, to start 
  a PDM to PCM conversion after we've only received 4 PDM samples (first port read), so 
  instead we'll be doing the decimation on the _previous_ data.

  One implication is for the PDM to PCM conversion we'll just need an extra word of buffer 
  space for each channel. So instead of having `unsigned pdm_buff[MIC_COUNT][8]` we have 
  the buffer be `unsigned pdm_buff[MIC_COUNT][9]`. Then to perform the first stage decimation 
  we just need to send `&pdm_buff[mic][1]` to the first stage FIR. Easy peasy.

  Do we really need a whole 16kHz sample-time of latency, or can we get away with one 96kHz 
  sample time of latency?  The main thing is that we need to keep the microphone data 
  synchronized. 

  What work needs to be done?

  For 8 microphones, the work is this:
  - 8 port reads (When these happen, of course, isn't really flexible)
  - unzip PDM data and put it in the 8 PDM buffers (can't really split this up)
  - 8 first stage decimations
  - 8 PDM buffer shifts

  Now the weird part is that with a decimation factor of 6, we do all this 6 times before we do a 
  second stage decimation on each of the 8 channels.
  Does that mean the switch should really have 48 cases..?  That doesn't really seem super practical..

*/



void pdm_rx( pdm_rx_config_t* config )
{
  const unsigned mic_count_log2 = 31 - clz(config->mic_count);

  unsigned t1, t2;

  while(1) {

    for(int k = 0; k < config->stage2.decimation_factor; k++){

      // Gather 32 PDM samples for each channel
      unsigned pdm_raw[8];

      // Read in PDM samples
      for(int s = 0; s < config->mic_count; s++){
        pdm_raw[s] = port_in(config->stage1.p_pdm_mics);
      }

      t1 = get_reference_time();

      // Unzip the PDM samples
      switch( mic_count_log2 ){
        case 3:
          // assert(0); // Not yet implemented
          break;
        case 2:
          // assert(0); // Not yet implemented
          break;
        case 1:
        {
          // assert(0); // Not yet implemented
          unsigned R = pdm_raw[0];
          unsigned S = pdm_raw[1];
          // unzip(R, S);
          asm volatile("unzip %0, %1, 0" : "=r"(R),"=r"(S) );
          config->stage1.pdm_buffer[0] = R;
          config->stage1.pdm_buffer[8] = S;
        }
        break;
        case 0:
          config->stage1.pdm_buffer[0] = pdm_raw[0];
          break;
          // No unzip required
      }

      // Apply first stage decimation
      for(int c = 0; c < config->mic_count; c++){
        
        const unsigned pdm_dex = 8 * c;
        const unsigned pcm_dex = config->stage2.decimation_factor * c + k;
        unsigned* pdm_start = (unsigned*) &config->stage1.pdm_buffer[ pdm_dex ];

        int32_t pcm_samp = fir_1x16_bit((int32_t*) pdm_start, 
                                        (int32_t*)config->stage1.fir_coef, 
                                        1);

        config->stage2.pcm_vector[ pcm_dex ] = pcm_samp;
      }

      // Shift pdm buffers up
      rotate_buffs(config->stage1.pdm_buffer, config->mic_count);
    }

    // We've gathered enough PCM samples for the next execution of the stage2 filter
    proc_pcm(config->stage2.pcm_vector);

    t2 = get_reference_time();
    proc_time = t2-t1;
  }
}