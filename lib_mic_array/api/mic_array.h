// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_H_
#define MIC_ARRAY_H_

#include <stdint.h>
#include <limits.h>
#include "fir_decimator.h"
#include "mic_array_frame.h"
#include "mic_array_defines.h"

/** PDM Microphone Interface component.
 *
 *  This task handles the interface to up to 8 PDM microphones whilst also decimating
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
 *  This task handles the interface to up to 8 PDM microphones whilst also decimating
 *  the PDM data by a factor of 4. The output is saved to a shared memory circular buffer
 *  given by shared_memory_array. The shared memory array
 *
 *  \param p_pdm_mics            The 8 bit wide port connected to the PDM microphones.
 *  \param shared_memory_array   A pointer to the location of the shared circular buffer.
 *  \param memory_size_log2      The number of int64_t in the shared memory log two.
 *  \param c_sync                The channel used for synchronizing the high resolution
 *                               delay buffer to the PDM input.
 */
void pdm_rx_hires_delay(
        in buffered port:32 p_pdm_mics,
        int64_t * unsafe shared_memory_array,
        unsigned memory_size_log2,
        streaming chanend c_sync);


#define HIRES_DELAY_TAP_COUNT 2

/*
 * High Resolution Delay config structure.
 */
typedef struct {
    unsigned memory_size_log2;              /**< The number of int64_t in the shared memory log two.*/
    unsigned active_delay_set;              /**< Used internally*/
    unsigned delay_set_head;                /**< Used internally*/
    unsigned long long n;                   /**< Used internally*/
    unsigned delays[2][MAX_NUM_CHANNELS];   /**< Holds the delays in a double buffer, selected by active_delay_set*/
} hires_delay_config;

/** High resolution delay component.
 *
 *  This task handles the application of a individual delays of up to 8 channels.
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
 *                              high resolution delay component.
 *  \param shared_memory_array  The pointer to the location of the shared circular buffer.
 */
void hires_delay(
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1,
        streaming chanend c_sync,
        hires_delay_config * unsafe config,
        int64_t * unsafe shared_memory_array);

/** Application side interface to high resolution delay.
 *
 *  This function is used by the client of the high resolution delay to set the delays.
 *
 *  \param config     A pointer to the hires_delay_config structure.
 *  \param delays     An array of the delays to be set.
 *  \param num_taps   The number of microphones. This is must be the same as the delays array.
 *  \returns          0 for success and 1 for buffer already contains pending delays.
 */
int hires_delay_set_taps(hires_delay_config * unsafe config, unsigned delays[], unsigned num_taps);

/** Four Channel decimator buffering type.
 *
 *  This type is used to describe the buffering mode.
 */
typedef enum {
    DECIMATOR_NO_FRAME_OVERLAP,   ///<  The frames have no overlap.
    DECIMATOR_HALF_FRAME_OVERLAP  ///<  The frames have a 50% overlap betweeen sequential frames.
} e_decimator_buffering_type;

/*
 * Note: to use a windowing function the COLA property must be obeyed, i.e. Coef[n] = 1-Coef[N-n]
 * where N is the array length. Only half the array need be specified as the windowing function
 * is assumed symmetric.
 */


/*
 * Four Channel decimator config structure.
 */
typedef struct {

    unsigned frame_size_log2;/**< The output frame size log2, i.e. A frame will contain 2 to the power of frame_size_log2 samples of each channel. */

    int apply_dc_offset_removal; /**< Remove the DC offset from the audio before the final decimation. Set to non-zero to enable. */

    int index_bit_reversal; /**< If non-zero then bit reverse the index of the elements within the frame. Used in the case of preparing for an FFT.*/

    int * unsafe windowing_function; /**< If non-null then this will apply a windowing function to the frame. Used in the case of preparing for an FFT. */

    //FIR Decimator

    unsigned fir_decimation_factor; /**< Final stage FIR Decimation factor*/

    const int *  unsafe coefs; /**< The coefficients for the FIR decimator */

    int apply_mic_gain_compensation; /**< Set to non-zero to apply microphone gain compensation. */

    int fir_gain_compensation; /**< 1.4.27 format for the gain compensation for the three satges of FIR. */

} decimator_config_common;

typedef struct {

    decimator_config_common * unsafe dcc;

    int * unsafe data;    /**< The data for the FIR decimator */

    int mic_gain_compensation[4]; /**< An array describing the relative gain compensation to apply to the microphones. The microphone with the least gain is defined as 0xffffffff(MAX_INT), all others are given as MAX_INT*min_gain/current_mic_gain.*/

    unsigned channel_count; /**< The count of enabled channels (0->4).  */

} decimator_config;

/** Four Channel Decimation component.
 *
 *  This task decimated the four channel input down to the desired sample rate.
 *  The decimation ratios are limited to 8*1, 8*2, 8*3, 8*4, 8*5, 8*6, 8*7 and 8*8.
 *  The channel c_frame_output is used to transfer pointers to frames decimator
 *  will save the output samples in the format given by the configuration.
 *
 *  \param c_from_pdm_interface      The channel where the decimated PDM of microphones 0-3 will
 *                                   be inputted bytewise.
 *  \param c_frame_output            The channel used to transfer pointers between the client of
 *                                   this task and this task.
 */
void decimate_to_pcm_4ch(
        streaming chanend c_from_pdm_interface,
        streaming chanend c_frame_output);



/** Four Channel Decimation initializer for audio frames.
 *
 *  This function call sets up the four channel decimators. After this has been called there
 *  will be a real time requirement on the task that owns c_pcm_0 and c_pcm_1 must call
 *  decimator_get_next_audio_frame() at the output sample rate.
 *
 *  \param c_from_decimator  The channels used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param decimator_count   The count of decimate_to_pcm_4ch() tasks.
 *  \param buffer            The buffer index. Always points to the index that is accessible to
 *                           the application.
 *  \param f_audio           An array of audio frames. Typically, of size two.
 *  \param buffering_type    Sets the decimator to double buffer(no overlap) or triple buffer (50% overlap)
 *                           the output frames.
 *
 */
void decimator_init_audio_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
        unsigned &buffer, frame_audio f_audio[], e_decimator_buffering_type buffering_type);


/** Four Channel Decimation audio frame exchange function.
 *
 *  This function handles the frame exchange between the decimate_to_pcm_4ch() tasks and the
 *  application. It returns a pointer to the most recently written frame. At the point the oldest
 *  frame is assumed out of scope of the application.
 *
 *  \param c_from_decimator  The channels used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param decimator_count   The count of decimate_to_pcm_4ch() tasks.
 *  \param buffer            The buffer index. Always points to the index that is accessible to
 *                           the application.
 *  \param f_audio           An array of audio frames. Typically, of size two.
 *  \param buffer_count      The size of the f_audio buffer(i.e. double buffering, etc)
 *
 *  \returns                 A pointer to the frame now owned by the application. That is, the most
 *                           recently written samples.
 */
frame_audio * alias decimator_get_next_audio_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
       unsigned &buffer, frame_audio * alias f_audio, unsigned buffer_count);

/** Four Channel Decimation initializer for complex frames.
 *
 *  This function call sets up the four channel decimators. After this has been called there
 *  will be a real time requirement on the task that owns c_pcm_0 and c_pcm_1 must call
 *  decimator_get_next_audio_frame() at the output sample rate.
 *
 *  \param c_from_decimator  The channels used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param decimator_count   The count of decimate_to_pcm_4ch() tasks.
 *  \param buffer            The buffer index. Always points to the index that is accessible to
 *                           the application.
 *  \param f_complex             An array of audio frames. Typically, of size two.
 *  \param buffering_type    Sets the decimator to double buffer(no overlap) or triple buffer (50% overlap)
 *                           the output frames.
 *
 */
void decimator_init_complex_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, frame_complex f_complex[], e_decimator_buffering_type buffering_type);

/** Four Channel Decimation complex frame exchange function.
 *
 *  This function handles the frame exchange between the decimate_to_pcm_4ch() tasks and the
 *  application. It returns a pointer to the most recently written frame. At the point the oldest
 *  frame is assumed out of scope of the application.
 *
 *  \param c_from_decimator  The channels used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param decimator_count   The count of decimate_to_pcm_4ch() tasks.
 *  \param buffer            The buffer index. Always points to the index that is accessible to
 *                           the application.
 *  \param f_complex         An array of audio frames. Typically, of size two.
 *  \param buffer_count      The size of the f_audio buffer(i.e. double buffering, etc)
 *
 *  \returns                 A pointer to the frame now owned by the application. That is, the most
 *                           recently written samples.
 */
frame_complex * alias decimator_get_next_complex_frame(streaming chanend c_from_decimator[], unsigned decimator_count,
     unsigned &buffer, frame_complex * alias f_complex, unsigned buffer_count);


/** Decimator configuration
 *
 *  This function initializes the decimators and configures then as per the decimator configuration
 *  structure thay are passed.
 *
 *  \param c_from_decimator  The channels used to transfer pointers between the application and
 *                           the decimate_to_pcm_4ch() task.
 *  \param decimator_count   The count of decimate_to_pcm_4ch() tasks.
 *  \param dc                The configuration for each decimator.
 */
void decimator_configure(streaming chanend c_from_decimator[], unsigned decimator_count,
        decimator_config dc[]);

#endif /* MIC_ARRAY_H_ */
