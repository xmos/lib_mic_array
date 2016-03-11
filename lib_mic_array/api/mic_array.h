// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_H_
#define MIC_ARRAY_H_

#include <stdint.h>
#include <limits.h>
#include "fir_coefs.h"
#include "mic_array_frame.h"

#ifndef MIC_ARRAY_HIRES_MAX_DELAY
    #define MIC_ARRAY_HIRES_MAX_DELAY 256
#endif

/** PDM Microphone Interface component.
 *
 *  This task handles the interface to up to 8 PDM microphones whilst also decimating
 *  the PDM data by a factor of 8. The output is sent via two channels to two receiving
 *  tasks.
 *
 *  \param p_pdm_mics        The 8 bit wide port connected to the PDM microphones.
 *  \param c_4x_pdm_mic_0    The channel where the decimated PDM of microphones 0-3 will
 *                           be outputted.
 *  \param c_4x_pdm_mic_1    The channel where the decimated PDM of microphones 4-7 will
 *                           be outputted. This can be null for 4 channel output.
 */
void mic_array_pdm_rx(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

/** High resolution delay component.
 *
 *  This task handles the application of individual delays for up to 16 channels.
 *  Each unit of delay represents one sample at the input sample rate, i.e. the rate
 *  at which the circular buffer is being updated. The maximum delay is given by the
 *  size of the circular buffer.
 *
 *  \param c_from_pdm_frontend     The channels connecting to the output of the PDM interface
 *  \param c_to_decimator          The channels connecting to the input of the 4 channel decimators.
 *  \param n                       The size of the two channel arrays, they must be the same.
 *  \param c_cmd                   The channel connecting the application to this task used for
 *                                 setting the delays.
 */
void mic_array_hires_delay(
        streaming chanend c_from_pdm_frontend[],
        streaming chanend c_to_decimator[],
        unsigned n,
        streaming chanend c_cmd);

/** Application side interface to high resolution delay.
 *
 *  This function is used by the client of the high resolution delay to set the delays.
 *
 *  \param c_cmd          The channel connecting the application to this task used for
 *                        setting the delays.
 *  \param delays         An array of the delays to be set. These must all be less than MIC_ARRAY_HIRES_MAX_DELAY.
 *  \param num_channels   The number of microphones. This must be the same as the delays array.
 */
void mic_array_hires_delay_set_taps(streaming chanend c_cmd, unsigned delays[], unsigned num_channels);

/** Four Channel decimator buffering type.
 *
 *  This type is used to describe the buffering mode. Note: to use a windowing function the constant-overlap-and-add property
 *  must be obeyed, i.e. Coef[n] = 1-Coef[N-n] where N is the array length. Only half the array need be
 *  specified as the windowing function is assumed to be symmetric.
 */
typedef enum {
    DECIMATOR_NO_FRAME_OVERLAP,   ///<  The frames have no overlap.
    DECIMATOR_HALF_FRAME_OVERLAP  ///<  The frames have a 50% overlap betweeen sequential frames.
} mic_array_decimator_buffering_t;

/** Four Channel decimator configuration structure.
 *
 *  This is used to describe the configuration that the group of synchronous decimators will use to process the PCM audio.
 */
typedef struct {

    unsigned frame_size_log2; /**< The output frame size log2, i.e. A frame will contain 2 to the power of frame_size_log2 samples of each channel. */

    int apply_dc_offset_removal; /**< Remove the DC offset from the audio before the final decimation. Set to non-zero to enable. */

    int index_bit_reversal; /**< If non-zero then bit reverse the index of the elements within the frame. Used in the case of preparing for an FFT.*/

    int * unsafe windowing_function; /**< If non-null then this will apply a windowing function to the frame. Used in the case of preparing for an FFT. */

    unsigned output_decimation_factor; /**< Final stage FIR Decimation factor. */

    const int * unsafe coefs; /**< The coefficients for the FIR decimator. */

    int apply_mic_gain_compensation; /**< Set to non-zero to apply microphone gain compensation. */

    int fir_gain_compensation; /**< 5.27 format for the gain compensation for the three stages of FIR filter. */

    mic_array_decimator_buffering_t buffering_type;  /**< The buffering type used for frame exchange. */

    unsigned number_of_frame_buffers;  /**< The count of frames used between the decimators and the application. */

} mic_array_decimator_conf_common_t;

/** Configuration structure unique to each of the 4 channel deciamtors.
 *
 *  This contains configuration that is channel specific, i.e. Gain compensation, etc.
 */
typedef struct {

    mic_array_decimator_conf_common_t * unsafe dcc;

    int * unsafe data;    /**< The data for the FIR decimator */

    int mic_gain_compensation[4]; /**< An array describing the relative gain compensation to apply to the microphones. The microphone with the least gain is defined as 0x7fffffff (INT_MAX), all others are given as INT_MAX*min_gain/current_mic_gain.*/

    unsigned channel_count; /**< The count of enabled channels (0->4).  */

} mic_array_decimator_config_t;

/** Four Channel Decimation component.
 *
 *  This task decimates the four channel input down to the desired output sample rate.
 *  The decimator has a fixed divide by 4 followed by a divide by decimation_factor where
 *  decimation_factor is greater than or equal to 2.
 *  The channel c_frame_output is used to transfer data and control information between the
 *  application and this task. It relies of shared memory for so the client of this task must
 *  be on the same tile as this task.
 *
 *  \param c_from_pdm_interface      The channel where the decimated PDM from pdm_rx task will be inputted.
 *  \param c_frame_output            The channel used to transfer data and control information between
 *                                   the client of this task and this task.
 */
void mic_array_decimate_to_pcm_4ch(
        streaming chanend c_from_pdm_interface,
        streaming chanend c_frame_output);


/** Four Channel Decimation initializer for raw audio frames.
 *
 *  This function call sets up the four channel decimators. After this has been called there
 *  will be a real time requirement on this task, i.e. this task must call
 *  mic_array_get_next_time_domain_frame() at the output sample rate multiplied by the frame size.
 *
 *  \param c_from_decimators  The channels used to transfer pointers between the application and
 *                           the mic_array_decimate_to_pcm_4ch() tasks.
 *  \param decimator_count   The count of mic_array_decimate_to_pcm_4ch() tasks.
 *  \param buffer            The buffer index. Always points to the index that is accessible to
 *                           the application (initialized internally)
 *  \param audio             An array of audio frames.
 *  \param dc                The array cointaining the decimator configuration for each decimator.
 *
 */
void mic_array_init_time_domain_frame(
        streaming chanend c_from_decimators[], unsigned decimator_count,
        unsigned &buffer, mic_array_frame_time_domain audio[],
        mic_array_decimator_config_t dc[]);


/** Four Channel Decimation raw audio frame exchange function.
 *
 *  This function handles the frame exchange between the mic_array_decimate_to_pcm_4ch() tasks and the
 *  application. It returns a pointer to the most recently written frame. After this point the oldest
 *  frame is assumed out of scope to the application.
 *
 *  \param c_from_decimators The channels used to transfer pointers between the application and
 *                           the mic_array_decimate_to_pcm_4ch() tasks.
 *  \param decimator_count   The count of mic_array_decimate_to_pcm_4ch() tasks.
 *  \param buffer            The buffer index (Used internally)
 *  \param audio             An array of audio frames.
 *  \param dc                The array cointaining the decimator configuration for each decimator.
 *
 *  \returns                 A pointer to the frame now owned by the application. That is, the most
 *                           recently written samples.
 */
mic_array_frame_time_domain * alias mic_array_get_next_time_domain_frame(
         streaming chanend c_from_decimators[], unsigned decimator_count,
        unsigned &buffer, mic_array_frame_time_domain * alias audio,
        mic_array_decimator_config_t dc[]);

/** Four Channel Decimation initializer for complex frames.
 *
 *  This function call sets up the four channel decimators. After this has been called there
 *  will be a real time requirement on this task, i.e. this task must call
 *  mic_array_get_next_frequency_domain_frame() at the output sample rate multiplied by the frame size.
 *
 *  \param c_from_decimators  The channels used to transfer pointers between the application and
 *                            the mic_array_decimate_to_pcm_4ch() tasks.
 *  \param decimator_count    The count of mic_array_decimate_to_pcm_4ch() tasks.
 *  \param buffer             The buffer index. Always points to the index that is accessible to
 *                            the application (initialized internally)
 *  \param f_fft_preprocessed An array of complex frames.
 *  \param dc                 The array cointaining the decimator configuration for each decimator.
 *
 */
void mic_array_init_frequency_domain_frame(streaming chanend c_from_decimators[], unsigned decimator_count,
     unsigned &buffer, mic_array_frame_fft_preprocessed f_fft_preprocessed[], mic_array_decimator_config_t dc[]);

/** Four Channel Decimation complex frame exchange function.
 *
 *  This function handles the frame exchange between the mic_array_decimate_to_pcm_4ch() tasks and the
 *  application. It returns a pointer to the most recently written frame. After this point the oldest
 *  frame is assumed out of scope to the application.
 *
 *  \param c_from_decimators   The channels used to transfer pointers between the application and
 *                            the mic_array_decimate_to_pcm_4ch() tasks.
 *  \param decimator_count    The count of mic_array_decimate_to_pcm_4ch() tasks.
 *  \param buffer             The buffer index (Used internally)
 *  \param f_fft_preprocessed An array of complex frames.
 *  \param dc                 The array cointaining the decimator configuration for each decimator.
 *
 *  \returns                  A pointer to the frame now owned by the application. That is, the most
 *                            recently written samples.
 */
mic_array_frame_fft_preprocessed * alias mic_array_get_next_frequency_domain_frame(
        streaming chanend c_from_decimators[], unsigned decimator_count,
     unsigned &buffer, mic_array_frame_fft_preprocessed * alias f_fft_preprocessed,
     mic_array_decimator_config_t dc[]);


/** Decimator configuration
 *
 *  This function initializes the decimators and configures them as per the decimator configuration
 *  structure thay are passed.
 *
 *  \param c_from_decimators  The channels used to transfer pointers between the application and
 *                           the mic_array_decimate_to_pcm_4ch() task.
 *  \param decimator_count   The count of mic_array_decimate_to_pcm_4ch() tasks.
 *  \param dc                The array cointaining the decimator configuration for each decimator.
 */
void mic_array_decimator_configure(
        streaming chanend c_from_decimators[],
        unsigned decimator_count,
        mic_array_decimator_config_t dc[]);

#endif /* MIC_ARRAY_H_ */
