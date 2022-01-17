
#include "mips.h"
#include "mic_array.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>

#if USE_C_VERSION

void print_mips()
{

  while(1){
    delay_seconds(1);

    uint64_t t = tick_count;
    uint64_t c = inst_count;

    // So, there are 8 cores running. But we are just going to pretend this core is using exactly 0 MIPS.
    // We're only monitoring the MIPS usage of one core (the one running count_mips()).

    // The idea here is that we assume the 6 cores that aren't this one or pdm_rx() are getting an
    // equal number of MIPS, and that any system MIPS leftover when we multiply the count_mips() MIPS
    // by 6 are being used by pdm_rx().

    const float usec = t / 100.0f;  // microseconds since the count started
    const float ipus = c / usec;    // instructions per microsecond
    const float mips = ipus;        // million instructions per second
                                    //  = million instructions per million microseconds
                                    //  = instructions per microsecond

    const float burnt_mips = 5 * mips;
    const float total_mips = 600;
    const float pdm_rx_mips = total_mips - burnt_mips;

    float pcm_sample_rate_khz = (pcm_sample_count / (usec / 1e3));
    // float pdm_sample_rate_khz = (pdm_sample_count / (usec / 1e3));

    // Note that because we're treating this thread as using 0 MIPS, the actual pdm_rx() MIPS should
    // be less than what is reported by some constant amount (doesn't depend on channel count or
    // filter taps, etc).
    
    printf(" pdm_rx: < %0.04f MIPS;\tPCM Sample Rate: %0.02f kHz;  proc_time: %u ticks\n", 
        pdm_rx_mips,
        pcm_sample_rate_khz,
        proc_time);
  }

}

#else


void print_mips()
{

  while(1){
    delay_seconds(1);

    uint64_t t = tick_count;
    uint64_t c = inst_count;

    // printf("%llu instructions in %llu ticks.\n", c, t);
    // printf("%llu instructions in %0.03f ms.\n", c, t / 100000.0f  ); 

    const float usec = t / 100.0f;  // microseconds since the count started
    const float ipus = c / usec;    // instructions per microsecond
    const float mips = ipus;        // million instructions per second
                                    //  = million instructions per million microseconds
                                    //  = instructions per microsecond

    float pcm_sample_rate_khz = (pcm_sample_count / (usec / 1e3));
    float pdm_sample_rate_khz = (pdm_sample_count / (usec / 1e3));

    // printf(" %0.04f MIPS free;  mic_array: %0.04f MIPS;  PCM samples: %u\n", 
    //     mips, 
    //     120 - mips, 
    //     pcm_sample_count);
    
    // printf("\tPCM Sample Rate: %0.02f kHz;  PDM Sample Rate: %0.02f kHz\n\n", 
    //     pcm_sample_rate_khz,
    //     pdm_sample_rate_khz);
  }

}

#endif