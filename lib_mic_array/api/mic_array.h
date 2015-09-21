#ifndef MIC_ARRAY_H_
#define MIC_ARRAY_H_

#include "defines.h"
#include "pcm_frame.h"

extern unsigned windowing_function[1<<FRAME_SIZE_LOG2];

void pdm_first_stage(
        in buffered port:8 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);

void pdm_first_stage_with_delay_and_sum(
        in buffered port:8 p_pdm_mics,
        unsigned long long * unsafe shared_memory_array,
        unsigned ch_memory_depth_log2,
        streaming chanend c_sync,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);


void pdm_first_stage_only_delay_and_sum(
        in buffered port:8 p_pdm_mics,
        unsigned long long * unsafe shared_memory_array,
        unsigned ch_memory_depth_log2,
        streaming chanend c_sync);

void delay_and_sum(
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1,
        streaming chanend c_sync,
        unsigned ch_memory_depth_log2,
        unsigned long long * unsafe p_taps,
        unsigned long long * unsafe p_shared_memory_array);

void pdm_to_pcm_4x_48KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output);
/*
void pdm_to_pcm_4x_16KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output);

void pdm_to_pcm_4x_8KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output);
*/
#endif /* MIC_ARRAY_H_ */
