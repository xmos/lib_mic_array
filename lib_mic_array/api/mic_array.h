#ifndef MIC_ARRAY_H_
#define MIC_ARRAY_H_

#include <stdint.h>
#include "fir_decimator.h"
#include "frame.h"
#include "defines.h"

extern unsigned windowing_function[1<<FRAME_SIZE_LOG2];

/** PDM Microphone Interface component.
 *
 *  This task handels the interface to up to 8 PDM microphones whilst also decimating
 *  the PDM data by a factor of 4. The output is sent across the channels in one byte
 *  per channel format.
 *
 *  \param p_pdm_mics        The 8 bit wide port connected to the PDM microphones.
 *  \param c_4x_pdm_mic_0    The channel where the decimated PDM of microphones 0-3 will
 *                           be outputted bytewise.
 *  \param c_4x_pdm_mic_1    The channel where the decimated PDM of microphones 4-7 will
 *                           be outputted bytewise.
 */
void pdm_rx(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);

/** PDM Microphone Interface component for high resolution delay.
 *
 *  This task handels the interface to up to 8 PDM microphones whilst also decimating
 *  the PDM data by a factor of 4. The output is saved to a shared memory cicular buffer
 *  given by shared_memory_array. The shared memory array
 *
 *  \param p_pdm_mics            The 8 bit wide port connected to the PDM microphones.
 *  \param shared_memory_array   A pointer to the location of the shared circluar buffer.
 *  \param memory_size_log2      The number of int64_t in the shared memory log two.
 *  \param c_sync                The channel used for synchronizing the high resolution
 *                               delay buffer to the PDM input.
 */
void pdm_rx_hires_delay(
        in buffered port:32 p_pdm_mics,
        int64_t * unsafe shared_memory_array,
        unsigned memory_size_log2,
        streaming chanend c_sync);

/*
 * High Resolution Delay config structure.
 */
typedef struct {
    unsigned memory_size_log2;              //The number of int64_t in the shared memory log two.
    unsigned active_delay_set;              //Used to select the initial delays from the delay double buffer
    unsigned delay_set_in_use;              //Used internally
    unsigned long long n;                   //Used internally
    unsigned delays[2][MAX_NUM_CHANNELS];   //Holds the delays in a double buffer, selected by active_delay_set
} hires_delay_config;

/** High resolution delay component.
 *
 *  This task handels the application of a individual delays of up to 8 channels.
 *  Each unit of delay represents one sample at the input sample rate, i.e. the rate
 *  at which the circular buffer is being updated. The maximum delay is given by the
 *  size of the circular buffer.
 *
 *  \param c_4x_pdm_mic_0       The channel where the decimated PDM of microphones 0-3 will
 *                              be outputted bytewise.
 *  \param c_4x_pdm_mic_1       The channel where the decimated PDM of microphones 4-7 will
 *                              be outputted bytewise.
 *  \param c_sync               The channel used for synchronizing the high resolution
 *                              delay buffer to the PDM input.
 *  \param config               The configuration structure describing the behaviour of the
 *                              high resoultion delay component.
 *  \param shared_memory_array  The pointer to the location of the shared circluar buffer.
 */
void hires_delay(
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1,
        streaming chanend c_sync,
        hires_delay_config * unsafe config,
        int64_t * unsafe shared_memory_array);
/*
 * Four Channel Deciamtor config structure.
 */
typedef struct {

    /*
     * The output frame size log2, i.e. A frame will contain 2 to the power of frame_size_log2
     * samples of each channel.
     */
    unsigned frame_size_log2;

    //Remove the DC offset from the audio before the final decimation.
    //Set to non-zero to enable.
    int apply_dc_offset_removal;

    //If non-zero then bit reverse the index of the elements within the frame.
    //Used in the case of perparing for an FFT.
    int index_bit_reversal;

    //If non-null then this will apply a windowing fucntion to the frame
    //Used in the case of perparing for an FFT.
    int * unsafe windowing_function;

    //FIR Decimator
    //This sets the deciamtion factor to the 8 times decimated input rate, i.e. if 768kHz
    //samples were inputted and 16kHz was the desired output then 3 would be the
    //fir_deciamtion_factor.
    unsigned fir_decimation_factor;

    //The coefficients for the FIR deciamtors.
    const int *  unsafe coefs;

    //The data for the FIR deciamtors
    int * unsafe data;    //This needs to be fir_decimation_factor*4*60*sizeof(int)//this need not be unsafe

    //set to non-zero to apply microphone gain compensation.
    int apply_mic_gain_compensation;

    //An array describing the relative gain compensation to apply to the microphones.
    //The microphone with the least gain is defined as 0xffffffff(MAX_INT), all others
    //are given as MAX_INT*min_gain/current_mic_gain.
    unsigned mic_gain_compensation[4];

} decimator_config;


/** Four Channel Decimation component.
 *
 *  This task decimated the four channel input down to the desired sample rate.
 *  The deciamtion ratios are limited to 8*1, 8*2, 8*3, 8*4, 8*5, 8*6, 8*7 and 8*8.
 *  The channel c_frame_output is used to transfer pointers to frames deciamtor
 *  will save the output samples in the format given by the configuration.
 *
 *  \param c_4x_pdm_mic      The channel where the decimated PDM of microphones 0-3 will
 *                           be inputted bytewise.
 *  \param c_frame_output    The channel used to transfer pointers between the client of
 *                           this task and this task.
 *  \param config            The configuration structure describing the behaviour of the
 *                           deciamtion component.
 */
void decimate_to_pcm_4ch(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output,
        decimator_config config);



/** Four Channel Decimation initializer for audio frames.
 *
 *  This function call sets up the four channel decimators. After this has been called there
 *  will be a real time requirement on the task that owns c_pcm_0 and c_pcm_1 must call
 *  decimator_get_next_audio_frame() at the output sample rate.
 *
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param buffer            The buffer index. Always points to the index that is accessable to
 *                           the application.
 *  \param audio             An array of audio frames. Typically, of size two.
 *
 */
void decimator_init_audio_frame(streaming chanend c_pcm_0, streaming chanend c_pcm_1,
        unsigned &buffer, frame_audio audio[]);


/** Four Channel Decimation audio frame exchange function.
 *
 *  This function handels the frame exchange between the decimate_to_pcm_4ch() tasks and the
 *  application. It returns a pointer to the most recently written frame. At the point the oldest
 *  frame is assumed out of scope of the application.
 *
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param buffer            The buffer index. Always points to the index that is accessable to
 *                           the application.
 *  \param audio             An array of audio frames. Typically, of size two.
 *
 *  \returns                 A pointer to the frame now owned by the application. That is, the most
 *                           recently written samples.
 */
frame_audio * alias decimator_get_next_audio_frame(streaming chanend c_pcm_0, streaming chanend c_pcm_1,
       unsigned &buffer, frame_audio * alias audio);

/** Four Channel Decimation initializer for complex frames.
 *
 *  This function call sets up the four channel decimators. After this has been called there
 *  will be a real time requirement on the task that owns c_pcm_0 and c_pcm_1 must call
 *  decimator_get_next_audio_frame() at the output sample rate.
 *
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param buffer            The buffer index. Always points to the index that is accessable to
 *                           the application.
 *  \param audio             An array of audio frames. Typically, of size two.
 *
 */
void decimator_init_complex_frame(streaming chanend c_pcm_0, streaming chanend c_pcm_1,
     unsigned &buffer, frame_complex f_audio[]);

/** Four Channel Decimation complex frame exchange function.
 *
 *  This function handels the frame exchange between the decimate_to_pcm_4ch() tasks and the
 *  application. It returns a pointer to the most recently written frame. At the point the oldest
 *  frame is assumed out of scope of the application.
 *
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param c_pcm_0           The channel used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param buffer            The buffer index. Always points to the index that is accessable to
 *                           the application.
 *  \param audio             An array of audio frames. Typically, of size two.
 *
 *  \returns                 A pointer to the frame now owned by the application. That is, the most
 *                           recently written samples.
 */
frame_complex * alias decimator_get_next_complex_frame(streaming chanend c_pcm_0, streaming chanend c_pcm_1,
     unsigned &buffer, frame_complex * alias f_complex);

#endif /* MIC_ARRAY_H_ */
