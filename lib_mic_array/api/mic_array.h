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

    //The output frame size log2.
    unsigned frame_size_log2;

    //Remove the DC offset from the audio before the final decimation.
    int apply_dc_offset_removal;

    //If non-zero then bit reverse the index of the elements within the frame.
    //Used in the case of perparing for an FFT.
    int index_bit_reversal;

    //If non-null then this will apply a windowing fucntion to the frame
    //Used in the case of perparing for an FFT.
    unsigned * unsafe windowing_function;

    //FIR Decimator
    //This sets the deciamtion factor of the 48000Hz signal.
    unsigned fir_decimation_factor;

    //The coefficients for the FIR deciamtors.
    unsigned * unsafe coefs[8]; //size 60*sizeof(int) //this need not be unsafe

    //The data for the FIR deciamtors
    int * unsafe data;    //This needs to be fir_decimation_factor*4*60*sizeof(int)//this need not be unsafe

    unsigned mic_gain_compensation[4];

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

void decimate_to_pcm_4ch(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output,
        decimator_config config);

#endif /* MIC_ARRAY_H_ */
