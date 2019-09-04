// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <stdint.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <string.h>
#include "mic_array.h"

const int N_LOOPS_TO_TEST = 50;
const unsigned ticks_per_s = 100000000;


in buffered port:32 p_pdm_mics   = XS1_PORT_1A;
unsafe{
    buffered port:32 * unsafe p_ptr = (buffered port:32 * unsafe) &p_pdm_mics;
}

//Note unusual casting of channel to a port. i.e. we output directly onto channel rather than port
unsafe{
    void call_mic_dual_pdm_rx_decimate(chanend c_mic_dual_pdm, streaming chanend c_ds_output[], streaming chanend c_ref_audio[]){
        p_ptr = ( buffered port:32 * unsafe ) &c_mic_dual_pdm;
        //printf("%p\n", *p_ptr);
        mic_dual_pdm_rx_decimate(*p_ptr, c_ds_output[0], c_ref_audio);
    }
}

unsigned get_random(unsigned x){
    crc32(x, -1, 0xEDB88320);
    return x;
}


void gen_pdm(chanend c_mic_dual_pdm){
    const unsigned pdm_hz = 3072000;
    const unsigned serdes_length = 32;
    const unsigned port_time_ticks = ticks_per_s / ((pdm_hz * 2)/ serdes_length); //2 because it's DDR

    unsigned random = 0xedededed;
    set_thread_fast_mode_on(); //burn!!

    timer tmr;
    unsigned time_trig;
    tmr :> time_trig;

    while(1){
        random = get_random(random);

        tmr when timerafter(time_trig) :> void;
        time_trig += port_time_ticks;
        outuint(c_mic_dual_pdm, random);
        
        random = get_random(random);

        tmr when timerafter(time_trig) :> void;
        time_trig += port_time_ticks;
        outuint(c_mic_dual_pdm, random);
    }
}


void test_timing(streaming chanend c_ds_output_dual[1]){
unsafe{
    // No init for mic_dual
    const unsigned fs = 16000;
    const unsigned max_ticks = ticks_per_s / fs;
    const int headroom_ticks = 5; //Arbitrary 50ns headroom
    long long total_headroom_ticks = 0;
    int min_head_room = INT_MAX;

    timer tmr;
    unsigned this_time, old_time;
    tmr :> this_time;
    old_time = this_time + max_ticks; //Set old time to be in future because first iter takes longer

    c_ds_output_dual[0] :> unsigned _; //Flush first value as we have to wait for pipe to fill

    set_thread_fast_mode_on(); //burn!!
    for (int i = 0; i < N_LOOPS_TO_TEST; i++) { //Start at -1 because we ignore first loop
        // Get mic_dual
        unsigned addr = 0;
        c_ds_output_dual[0] :> addr;
        tmr :> this_time;
        unsigned time = this_time - old_time;
        printintln(time);
        int this_headroom = (int)max_ticks - (int)time;
        if (i >= 0)total_headroom_ticks += this_headroom;
        if (this_headroom < min_head_room) min_head_room = this_headroom;
        if (this_headroom < headroom_ticks){
            printf("FAIL: mic_dual took: %u ticks on cycle %d, limit: %u\n", time, i, max_ticks + headroom_ticks);
        }
        old_time = this_time;
    }
    // All good
    printf("Test PASS with average headroom_ticks of %d over %d iterations, worst case %d\n", (int)(total_headroom_ticks / N_LOOPS_TO_TEST), N_LOOPS_TO_TEST, min_head_room);
    exit(0);
}//unsafe
}

void ref_audio(streaming chanend c_ref_audio[]){
  set_thread_fast_mode_on(); //burn!!
  while(1){
    for(unsigned i=0;i<2;i++) c_ref_audio[i] :> int _;
    for(unsigned i=0;i<2;i++) c_ref_audio[i] <: 0;
  }
}

int main(){
    chan c_mic_dual_pdm; //This uses primatives rather than XC operators so has normal chan
    streaming chan c_ds_output_dual[1],  c_ref_audio[2];

    par {
        gen_pdm(c_mic_dual_pdm);

        //mic_dual
        ref_audio(c_ref_audio);
        call_mic_dual_pdm_rx_decimate(c_mic_dual_pdm, c_ds_output_dual, c_ref_audio);
        test_timing(c_ds_output_dual);
        par (int i = 0; i < 4; i++) {{set_thread_fast_mode_on(); while(1);}} //burn remaining threads
    }
    return 0;
}
