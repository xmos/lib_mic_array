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

typedef struct {
    unsigned active_delay_set;
    unsigned memory_depth_log2;
    unsigned delay_set_in_use;
    unsigned long long n;
    unsigned delays[2][MAX_NUM_CHANNELS];
} hires_delay_config;

void hires_delay(
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1,
        streaming chanend c_sync,
        hires_delay_config * unsafe config,
        unsigned long long * unsafe p_shared_memory_array);

typedef struct {
    unsigned frame_size_log2;
    int apply_dc_offset;
    int index_bit_reversal;
    unsigned * unsafe windowing_function;
} decimator_config;

/*
 * Takes a channel from a integrated multi channel PDM source and
 * outputs a frame of PCM at 48KHz.
 *
 * The output is in the range of:
 * -2139095040 to 2139095040  or: 0x8080000 to 0x7f80000.
 * Which is 99.6% of full scale.
 */
void decimate_to_pcm_4ch_48KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output,
        decimator_config config
);

void decimate_to_pcm_4ch_16kHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output,
        decimator_config config);


/*
void decimate_to_pcm_4ch_8KHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output);
*/
#endif /* MIC_ARRAY_H_ */
