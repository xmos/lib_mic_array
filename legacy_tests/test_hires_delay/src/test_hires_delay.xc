// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include <platform.h>
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>

#define S_CHANS ((MIC_ARRAY_NUM_MICS + 3)/4)

static unsigned make_id(unsigned sample_number, unsigned chan_number){
    return (sample_number&0xfffffff) + (chan_number<<28);
}

static void unmake_id(unsigned id, unsigned &sample_number, unsigned &chan_number){
   sample_number = id&0xfffffff;
   chan_number= id>>28;
}

void producer(streaming chanend c_from_pdm_frontend[]){
    unsigned i=0;
    while(1){
        for(unsigned ch=0;ch < MIC_ARRAY_NUM_MICS/S_CHANS;ch++){
            for(unsigned c=0;c<S_CHANS;c++){

                c_from_pdm_frontend[c] <: make_id(i, c*4 + ch);
            }
        }
        i++;
    }
}

static unsigned pseudo_random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return x;
}

void test(streaming chanend c_to_decimator[],
        streaming chanend c_cmd){
    unsigned sample = 0;
    unsigned set_delays[MIC_ARRAY_NUM_MICS] = {0, 0, 0, 0, 0, 0, 0, 0};
    unsigned real_delays[MIC_ARRAY_NUM_MICS] = {0, 0, 0, 0, 0, 0, 0, 0};
    unsigned x=0x12345678;

#define PASS_CONDITION 512

    unsigned successes = 0;

    while(1){
        mic_array_hires_delay_set_taps(c_cmd, set_delays, MIC_ARRAY_NUM_MICS);
        int correct = 0;
        while(!correct){
            unsigned result[MIC_ARRAY_NUM_MICS] = {0};
            unsigned id;
            for(unsigned ch=0;ch < MIC_ARRAY_NUM_MICS/S_CHANS;ch++){
                for(unsigned c=0;c<S_CHANS;c++){
                    c_to_decimator[c] :> id;
                    unsigned s, n;
                    unmake_id(id, s, n);
                    result[n] = s;
                }
            }
            correct = 1;
            for(unsigned ch=0;ch<MIC_ARRAY_NUM_MICS;ch++)
                correct &= (result[ch] == (sample - real_delays[ch]));

            sample++;

            if(sample == (PASS_CONDITION*4)){
                printf("Failure\n");
                _Exit(1);
            }
        }

        successes++;

        if(successes == PASS_CONDITION){
            printf("Pass\n");
            _Exit(0);
        }

        for(unsigned ch=0;ch<MIC_ARRAY_NUM_MICS;ch++)
            set_delays[ch] = (pseudo_random(x)&0xfff)%(sample+1);

        for(unsigned ch=0;ch<MIC_ARRAY_NUM_MICS;ch++){
            if(set_delays[ch] < MIC_ARRAY_HIRES_MAX_DELAY){
                real_delays[ch] = set_delays[ch];
            } else {
                real_delays[ch] = MIC_ARRAY_HIRES_MAX_DELAY-1;
            }
        }
    }
}

int main(){
    streaming chan c_from_pdm_frontend[S_CHANS];
    streaming chan c_to_decimator[S_CHANS];
    streaming chan c_cmd;
    par {
        producer(c_from_pdm_frontend);
        test(c_to_decimator, c_cmd);
        mic_array_hires_delay(c_from_pdm_frontend, c_to_decimator, S_CHANS, c_cmd);
    }
    return 0;
}
