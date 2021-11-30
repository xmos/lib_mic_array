
#include "mips.h"
#include "mic_array.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>

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

    
    
    printf(" %0.04f MIPS free;  mic_array: %0.04f MIPS;  PCM samples: %u\n", 
        mips, 
        120 - mips, 
        pcm_sample_count);
    
    printf("\tPCM Sample Rate: %0.02f kHz;  PDM Sample Rate: %0.02f kHz\n\n", 
        pcm_sample_rate_khz,
        pdm_sample_rate_khz);
  }

};