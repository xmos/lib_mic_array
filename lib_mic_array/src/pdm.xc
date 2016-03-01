// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <stdint.h>

extern void pdm_rx_asm(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

void mic_array_pdm_rx(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1){
    //This will never return
    pdm_rx_asm(p_pdm_mics,
            c_4x_pdm_mic_0,c_4x_pdm_mic_1);
}

extern void pdm_rx_asm_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

//Not exposed to the API - only intended for testing.
void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1){
    //This will never return
    pdm_rx_asm_debug(c_not_a_port,
                c_4x_pdm_mic_0,c_4x_pdm_mic_1);
}
