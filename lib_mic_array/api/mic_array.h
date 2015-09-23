#ifndef MIC_ARRAY_H_
#define MIC_ARRAY_H_

#include "defines.h"
#include "frame.h"

extern unsigned windowing_function[1<<FRAME_SIZE_LOG2];

void pdm_rx(
        in port p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);

void pdm_rx_with_hires_delay(
        in port p_pdm_mics,
        unsigned long long * unsafe shared_memory_array,
        unsigned ch_memory_depth_log2,
        streaming chanend c_sync,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);


void pdm_rx_only_hires_delay(
        in port p_pdm_mics,
        unsigned long long * unsafe shared_memory_array,
        unsigned ch_memory_depth_log2,
        streaming chanend c_sync);

void hires_delay(
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1,
        streaming chanend c_sync,
        unsigned ch_memory_depth_log2,
        unsigned long long * unsafe p_taps,
        unsigned long long * unsafe p_shared_memory_array);

typedef struct {
    unsigned frame_size_log2;
    int apply_dc_offset;
    int index_bit_reversal;
    unsigned * unsafe windowing_function;
} decimator_config;

void decimate_to_pcm_4ch_48KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output,
        decimator_config config
);
/*
void decimate_to_pcm_4ch_16KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output);

void decimate_to_pcm_4ch_8KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output);
*/
#endif /* MIC_ARRAY_H_ */
