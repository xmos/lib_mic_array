// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <stdint.h>

extern void pdm_rx_asm(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

void pdm_rx(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1){
    //This will never return
    pdm_rx_asm(p_pdm_mics,
            c_4x_pdm_mic_0,c_4x_pdm_mic_1);
}

void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1){

    asm volatile ("mov r0, %0; mov r1, %1; mov r2, %2; bl pdm_rx_asm"::
            "r"(c_not_a_port),"r"(c_4x_pdm_mic_0),"r"(c_4x_pdm_mic_1));
}
