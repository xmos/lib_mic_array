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


/**
 * @brief Get size requirement for framing buffer.
 * 
 * This macro gives the number of words of memory required to contain the framing
 * state for the specified frame count, frame size (sample count) and number of
 * channels.
 * 
 * The intended use for this macro is to declare a buffer which can then be
 * cast to a `ma_framing_context_t*`.
 * 
 * @code
 *  // 2 mics; 16 samples/frame, 2 frames
 *  uint32_t framing_buffer[MA_FRAMING_BUFFER_SIZE(2, 16, 2);
 *  ma_framing_context_t* framing_ctx = (ma_framing_context_t*) &framing_buffer[0];
 * @endcode
 * 
 * @param CHAN_COUNT    Number of channels to be framed.
 * @param FRAME_SIZE    Number of samples in a frame.
 * @param FRAME_COUNT   Number of frames to keep in the frame buffer.
 * 
 * @returns Number of words required to hold framing state.
 */
#define MA_FRAMING_BUFFER_SIZE(CHAN_COUNT, FRAME_SIZE, FRAME_COUNT)     \
              (3 + sizeof(ma_frame_format_t)                            \
                 + ((CHAN_COUNT)*(FRAME_SIZE)*(FRAME_COUNT)))


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
 * @brief State context for Mic Array Framing module.
 * 
 * This struct represents the state information required for mic array framing.
 * It is used by the decimator (@see @todo) (if enabled), or it may be used 
 * independently, as it does not rely on the decimator state.
 * 
 * Samples are supplied to the frame one at a time (a 'sample' here being a 
 * vector quantity containing one value for each channel). When a frame is 
 * filled, that frame is emited through a call to `ma_proc_frame()`. 
 * 
 * The default behavior of `ma_proc_frame()` is to send the frame's content 
 * over a channel using the frame transfer API (@see `frame_transfer.h`). 
 * However, `ma_proc_frame()` may be overridden with a user implementation.
 * 
 * Further, the channel on which to transmit the frame is supplied to 
 * `ma_proc_frame()` (via `ma_framing_add_and_signal()`) as a 
 * `ma_proc_frame_ctx_t`, which is `typedef`ed to `chanend_t` by default, but 
 * may also be overridden by the user to another type (for example, if FreeRTOS 
 * is used, a queue type may be prefered). 
 * 
 * @par Using Mic Array Framing w/ Decimator Task
 * 
 * A typical usage scenario is that an application wishes to receive framed
 * audio directly from the output of the decimator (@see `ma_decimator_task()`).
 * 
 * Setting the `framing` field of `ma_decimator_context_t` to `NULL` will 
 * disable framing. Setting the `framing` field of `ma_decimator_context_t` to
 * point to an initialized instance of `ma_framing_context_t` will enable 
 * framing in the decimator.
 * 
 * If an app wishes to enable framing in the decimator, it may either directly
 * initialize the framing context using `ma_framing_context_init()`, or it may
 * be allocated and initialized by using the `MA_STATE_DATA()` and 
 * `ma_decimator_context_setup()` helper macros.
 * 
 * @par Using Mic Array Framing
 * 
 * The first step to using framing is to create a buffer to hold the framing 
 * state. The size of that buffer will depend on the frame format and the 
 * number of frames to be stored. The `MA_FRAMING_BUFFER_SIZE()` macro can be
 * used to determine the required number of words.
 * 
 * @code
 *  // 3 channels; 256 samples/frame; 2 frame buffers
 *  #define MICS            3
 *  #define SAMP_PER_FRAME  256
 *  #define FRAME_BUFFS     2
 *  int32_t framing_buffer[MA_FRAMING_BUFFER_SIZE(MICS, SAMP_PER_FRAME, FRAME_BUFFS)];
 *  ma_framing_context_t* framing_ctx = (ma_framing_context_t*) &framing_buffer[0];
 * @endcode
 * 
 * The framing context should be initialized once, before any calls to 
 * `ma_framing_add_sample()` are made.
 * 
 * @code
 *  ma_framing_init(framing_ctx, MICS, SAMP_PER_FRAME, FRAME_BUFFS);
 * @endcode
 * 
 * Subsequently, each time a new sample of audio data becomes available, 
 * `ma_framing_add_sample()` is used to add the sample to the current
 * frame.
 * 
 * @code
 *  int32_t sample[MICS];
 *  chanend_t output_channel = ...;
 *  while(1){
 *    // ... sample[] gets new data ...
 *    ma_framing_add_sample(framing_ctx, output_channel, sample);
 *    // ...
 *  }
 * @endcode
 * 
 * @par Frame Buffers
 * 
 * This component allows the user to specify the number of frame buffers 
 * through which the framing logic will cycle as frames are filled up.
 * 
 * If `N` frame buffers are used, when a frame has completed and is returned
 * via `ma_framing_add_sample()` or `ma_framing_add_and_signal()`, that frame
 * is safe from being clobbered only until framing cycles through each other
 * frame and the original frame becomes active again, approximately `N-1` 
 * frame times.
 * 
 * By default, if framing is used with the decimator, the thread will attempt
 * to transmit the completed frame over a channel by value (rather than a 
 * pointer to the data) to another thread. In this case, a single frame buffer
 * will suffice, as the decimator thread cannot produce any new samples until
 * the frame has been completely transmitted.
 * 
 * @par Overriding ma_proc_frame()
 * 
 * @todo
 * 
 * 
 */
typedef struct {

  /**
   * Current state information.
   */
  struct {
    /** The index of the frame buffer that is currently active. */
    unsigned frame;
    /** The index of the next sample to be added in the currently active frame */
    unsigned sample;
  } current;

  /**
   * Static configuration information.
   */
  struct {
    /** Format of the frame buffers (i.e. channel count, sample count, layout) */
    ma_frame_format_t format;
    /** Number of frame buffers */
    unsigned frame_count;
  } config;

  /**
   * Pointer to the frame buffers.
   * 
   * Note: this assumes that the actual frame buffers are immediately after 
   * this struct in memory, as is the case when casting a buffer allocated using
   * the `MA_FRAMING_BUFFER_SIZE()` macro to a `ma_framing_context_t*`.
   */
  int32_t frames[0];
} ma_framing_context_t;


/**
 * @brief Initialize a mic array framing context.
 * 
 * This must be called for a `ma_framing_context_t` prior to calls to 
 * `ma_framing_add_sample()` or `ma_framing_add_and_signal()`.
 * 
 * When using framing with the decimator task, if the `ma_decimator_context_setup()`
 * helper macro is used, this function will be called for you.
 * 
 * @param ctx           Context to be initialized.
 * @param channel_count Number of channels in each audio frame.
 * @param sample_count  Number of samples in each audio frame.
 * @param frame_count   Number of frame buffers to cycle through.
 */
void ma_framing_init(
  ma_framing_context_t* ctx,
  const unsigned channel_count,
  const unsigned sample_count,
  const unsigned frame_count);


/**
 * @brief Add a sample to the current frame.
 * 
 * This function adds a new sample (a vector containing 1 element per audio
 * channel) to the current frame. If the new sample completed the current
 * frame, a pointer to that frame's frame buffer will be returned. Otherwise,
 * if more samples are needed to complete the current frame, `NULL` is 
 * returned.
 * 
 * `ctx` must have already been initialized.
 * 
 * @param ctx     Mic array framing context.
 * @param sample  New sample to be added to the current frame.
 * 
 * @returns Pointer to completed frame or `NULL`.
 */
int32_t* ma_framing_add_sample(
    ma_framing_context_t* ctx,
    int32_t sample[]);


/**
 * @brief Add a sample to the current frame and call `ma_proc_frame()` if the
 *        frame is complete.
 * 
 * This function behaves the same as `ma_framing_add_sample()` except that it
 * additionally will make a call to `ma_proc_frame()` if the current frame has
 * been completed.
 * 
 * `c_context` is the application-supplied context against which the call will
 * be made.
 * 
 * `ctx` must have already been initialized.
 * 
 * @param ctx         Mic array framing context.
 * @param c_context   Application context.
 * @param sample      New sample to be added to the current frame.
 * 
 * @returns  Pointer to completed frame or `NULL`.
 */
static inline
int32_t* ma_framing_add_and_signal(
  ma_framing_context_t* ctx,
  ma_proc_sample_ctx_t c_context,
  int32_t sample[]);


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


/**
 * @brief Process completed frame of audio.
 * 
 * This function is called automatically by `ma_framing_add_and_signal()` when
 * new audio frames are ready.
 * 
 * This function has a default implementation, but if an application wishes to
 * use a custom implementation, the default definition may be suppressed by
 * defining `MA_CONFIG_SUPPRESS_PROC_FRAME` to `1`.
 * 
 * Further, the context type, `ma_proc_frame_ctx_t`, can be overridden by 
 * defining the `MA_PROC_FRAME_CONTEXT_TYPE` flag to the desired type.
 * 
 * If the type of `ma_proc_frame_ctx_t` is overridden to anything other than 
 * `chanend_t`, the application must provide its own implementation of 
 * `ma_proc_frame()`.
 * 
 * @par Default Behavior
 * 
 * The behavior of the default implementation is to call `ma_frame_tx_s32()`,
 * waiting for some consumer in another thread to receive the frame data 
 * over the channel `c_context`.
 * 
 * In this case, the frame can be received by another thread with a (blocking)
 * call to `ma_frame_rx_s32()` or related function from `frame_transfer.h`.
 * 
 * @param c_context     Application context.
 * @param pcm_frame     The frame to be processed.
 * @param frame_format  Format information for `pcm_frame`.
 */
void ma_proc_frame(
    ma_proc_frame_ctx_t c_context,
    int32_t* pcm_frame,
    const ma_frame_format_t* frame_format);


  
#if defined(__XC__) || defined(__cplusplus)
}
#endif

#include "impl/framing_impl.h"