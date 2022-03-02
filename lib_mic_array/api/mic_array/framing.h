#pragma once


#include "mic_array/types.h"

#include <stdint.h>

/**
 * @brief Mic Array Framing
 * 
 * This module contains functions associated with packing audio samples together
 * into frames so that subsequent stages of the audio pipeline may process them
 * in blocks.
 * 
 */


#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif


/**
 * @brief Frame Layout Type
 * 
 * A frame of audio is a 2 dimensional object in which one of the dimensions
 * corresponds to the audio channel index, and the other dimension 
 * corresponds to the sample time. The ordering of those two dimensions will 
 * determine how the data is laid out in memory.
 * 
 * The values of this enum are intended to signal the memory layout for a
 * frame buffer.
 * 
 * Some use cases may require that all data corresponding to the same time
 * tick be adjacent in memory, while others may prefer or require that all
 * data associated with the same channel is adjacent in memory.
 * 
 * For example, if a stage in the audio pipeline implements some sample-by-
 * sample algorithm, keeping data for the same time step adjacent may allow
 * parallelization using the VPU. On the other hand, if a processing stage
 * starts by performing a real FFT on each channel, it may be preferable to
 * have the channels be contiguous in memory (Note: this is ignoring the 
 * advanced use case where channels may be FFTed in pairs).
 */
typedef enum {
  /**
   * Frame is laid out with time steps being contiguous in memory. I.e. 
   * layout is equivalent to:
   * 
   * @code
   *    int32_t audio_frame[SAMPLES_PER_FRAME][CHANNEL_COUNT];
   * @endcode
   */
  MA_LYT_CHANNEL_SAMPLE,
  /**
   * Frame is laid out with each channel being contiguous in memory. I.e.
   * layout is equivalent to:
   * 
   * @code
   *    int32_t audio_frame[CHANNEL_COUNT][SAMPLES_PER_FRAME];
   * @endcode
   */
  MA_LYT_SAMPLE_CHANNEL
} ma_frame_layout_e;


/**
 * @brief Specifies geometry of an audio frame.
 * 
 * A `ma_frame_format_t` object specifies the full shape and size of an audio
 * frame.  An object of this type together with an `int32_t` pointer are 
 * adequate to fully access the contents of an (`int32_t`) audio frame whose 
 * dimensions aren't necessarily known at compile time.
 */
typedef struct {
  /** Number of channels represented in the frame. */
  unsigned channel_count;
  /** Number of samples/time steps represented in the frame. */
  unsigned sample_count;
  /** Memory layout of audio data. */
  ma_frame_layout_e layout;
} ma_frame_format_t;



/**
 * @brief Create and initialize new `ma_frame_format_t`.
 * 
 * @param[in] channel_count   Number of channels represented in frame.
 * @param[in] sample_count    Number of samples (time steps) represented in frame.
 * @param[in] layout          Memory layout of data.
 * 
 * @returns Initialized `ma_frame_format_t`.
 */
static inline
ma_frame_format_t ma_frame_format(
    const unsigned channel_count,
    const unsigned sample_count,
    const ma_frame_layout_e layout);

  
#if defined(__XC__) || defined(__cplusplus)
}
#endif

#include "impl/framing_impl.h"