#pragma once

#include "xs3_math.h"

#include "etc/xcore_compat.h"

#include "mic_array/framing.h"
#include "mic_array/dc_elimination.h"

#include <stdint.h>

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif //__XC__


/**
 * @brief Get size requirement for PDM history buffer.
 * 
 * The first stage decimator is a 256-tap FIR filter, so the decimator needs a
 * buffer to keep a 256 sample history for each microphone channel. When 
 * initializing the decimator context, the user must provide pointer to a buffer
 * large enough to store that history.
 * 
 * This macro gives the number of _words_ of history required, given the number
 * of microphone channels.
 * 
 * @param MIC_COUNT   Number of microphone channels.
 * 
 * @returns Number of words to allocate for the PDM history buffer.
 */
#define MA_PDM_HISTORY_SIZE_WORDS(MIC_COUNT)  ( 8*(MIC_COUNT) )



/**
 * @brief Container for decimator task configuration and state.
 * 
 */
typedef struct {

  /**
   * Number of microphone channels being processed.
   */
  unsigned mic_count;

  struct {
    /** Pointer to Stage 1 filter coefficient block. */
    uint32_t* filter_coef;
    /** Pointer to PDM history buffer. */
    uint32_t* pdm_history;
  } stage1;

  struct {
    /** Stage 2 filter's decimation factor. */
    unsigned decimation_factor;
    /** 
     * Pointer to array of `xs3_filter_fir_s32_t`, the stage 2 filters 
     * associated with the microphone channels.
     */ 
    xs3_filter_fir_s32_t* filters;
  } stage2;

  /**
   * Pointer to framing context, if framing is enabled, otherwise `NULL` if
   * framing is disabled.
   */
  ma_framing_context_t* framing;
  /**
   * Pointer to array of DC offset elimination filter states, one per channel,
   * or `NULL` if DC offset elimination filter is not wanted.
   */
  dcoe_chan_state_t* dc_elim;

} ma_decimator_context_t;


/**
 * @brief Initialize decimator context.
 * 
 * Because properties like the microphone count, second stage decimation factor
 * and frame size are not known at compile time, `ma_decimator_context_t` keeps
 * pointers to external buffers for most of its state information. This function 
 * initializes the decimator context `context` by providing it with the values 
 * and pointers it needs to operate.
 * 
 * This function does _not_ initialize the stage 2 filters, framing context or 
 * DC elimination states. These must be initialized separately prior to starting
 * the decimator thread.
 * 
 * @par Recommended Usage
 * 
 * Typically applications will need not call this function directly. Instead,
 * if the `MA_STATE_DATA()` macro is used to allocate the required buffers 
 * (recommended), the `ma_decimator_context_setup()` macro may be used to 
 * initialize both the decimator context, and its sub-components (filters,
 * framing, DC elimination). See @ref `mc_decimator_context_setup()` for more
 * details.
 * 
 * @par Parameter Details
 * 
 * `context` is the decimator context to be initialized.
 * 
 * `mic_count` is the number of microphone channels being processed by this
 * decimator.
 * 
 * `stage2_decimator_factor` is the decimation factor for the second stage
 * decimation filter. If the default second stage filter is used 
 * (`mic_array/etc/filters_default.h`), this value should be 
 * `STAGE2_DEC_FACTOR`.
 * 
 * `stage1_filter_coef` is a pointer to the first stage filter coefficient 
 * block. The first stage decimator has a fixed decimation factor of 32 
 * (`STAGE1_DEC_FACTOR`), and a fixed tap count of 256 (`STAGE1_TAP_COUNT`). If
 * the default first stage filter is used (`mic_array/etc/filters_default.h`),
 * this value should be `stage1_coef`.
 * 
 * `pdm_history` is a pointer to a buffer used to store the filter state for the
 * first stage decimator. A single contiguous buffer is used for all mic 
 * channels. 8 words are required for each channel. The provided macro
 * `MA_PDM_HISTORY_SIZE_WORDS()` gives the size requirement for this buffer (in
 * words) given the number of microphones.
 * 
 * `stage2_filters` is a pointer to an array of `mic_count` 
 * `xs3_filter_fir_s32_t` filter objects.
 * 
 * `framing` controls whether audio data will be delivered in frames or 
 * sample-by-sample. If `framing` is `NULL`, the audio stream will be sent to
 * the subsequent stage of the pipeline as each sample becomes ready (i.e. after
 * second stage decimation). If `framing` is not `NULL`, it must point to an
 * `ma_framing_context_t` object which keeps the state and configuration info
 * for the framing process.
 * 
 * `dcoe_states` controls whether a DC offset elimination filter is applied to
 * each channel after the second stage decimator. If `dcoe_states` is `NULL`, DC
 * offset elimination is disabled. If `dcoe_states` is not `NULL`, it must point
 * to an array of `mic_count` `dcoe_chan_state_t` objects, which track each 
 * channel's filter state.
 * 
 * The `xs3_filter_fir_s32_t` objects pointed to by `stage1_filter_coef`, the
 * `ma_framing_context_t` object pointed to by `framing` (if not `NULL`), and 
 * the `dcoe_chan_state_t` objects pointed to by `dcoe_states` (if not `NULL`)
 * may each be initialized before or after this call, but must be initialized
 * (if not `NULL`) prior to starting the decimator thread.
 * 
 * @param context       Decimator context to be initialized.
 * @param mic_count     Number of microphones being captured.
 * @param stage2_decimator_factor Decimation factor for second stage filter.
 * @param stage1_filter_coef  Pointer to stage 1 filter coefficients block.
 * @param pdm_history     Pointer to PDM history buffer.
 * @param stage2_filters  Pointer to array of stage 2 filters.
 * @param framing       Pointer to framing context, or `NULL`.
 * @param dcoe_states   Pointer to array of DC offset elimination states, or 
 *                      `NULL`.
 */
void ma_decimator_context_init(
    ma_decimator_context_t* context,
    const unsigned mic_count,
    const unsigned stage2_decimation_factor,
    const uint32_t* stage1_filter_coef,
    uint32_t* pdm_history,
    xs3_filter_fir_s32_t* stage2_filters,
    ma_framing_context_t* framing,
    dcoe_chan_state_t* dcoe_states);


/**
 * @brief Decimator Thread
 * 
 * This function loops forever (does not return) receiving batches of samples
 * via `c_pdm_data`, processes them with the first and second stage decimators
 * and sends the results out via app_context.
 * 
 * `dec_context` must be initialized prior to calling this function. It can be 
 * initialized using one of `ma_decimator_context_init()` or  
 * `ma_decimator_context_setup()`.
 * 
 * The decimator will receive buffers containing blocks of PDM samples from 
 * `c_pdm_data`, which must be a chanend for a streaming channel. The buffers
 * are passed by reference from the PDM rx service (either a `pdm_rx_task()` if
 * in thread mode, or the PDM rx ISR if in interrupt mode).
 * 
 * `app_context` is an application context for processing the frames or samples 
 * produced by the decimator thread. By default `ma_proc_sample_ctx_t` is 
 * `typedef`ed to be a `chanend_t` which is used to transfer the output to the 
 * next stage of processing.
 * 
 * The type of `ma_proc_sample_ctx_t` can be overridden by an application (see 
 * @ref `MA_PROC_SAMPLE_CONTEXT_TYPE` in `mic_array/types.h`). In that case, 
 * `ma_proc_sample()` must also be overridden to use the user-defined context.
 * Doing this allows an application (e.g. a FreeRTOS-based app) to use a 
 * mechanism other than channels (e.g. FreeRTOS queues) to move audio data
 * around.
 * 
 * @param dec_context       Initialized decimator context.
 * @param c_pdm_data        Streaming chanend to receive PDM buffers on.
 * @param app_context       Application context for decimator output.
 */
void ma_decimator_task( 
    ma_decimator_context_t* dec_context,
    chanend_t c_pdm_data,
    ma_proc_sample_ctx_t app_context);




#ifndef MA_FRAME_BUFF_COUNT_DEFAULT
#define MA_FRAME_BUFF_COUNT_DEFAULT   2
#endif

/**
 * Several components and sub-components of lib_mic_array require the application to 
 * supply buffers whose size depends upon application parameters. Rather than 
 * requiring applications to `#define` macros indicating e.g. the number of 
 * microphones and the stage 2 decimation factor (and preventing run-time 
 * reconfiguration), this macro is provided to simplify configuration.
 * 
 * Typically, this will be used in conjunction with 
 * `ma_decimator_context_setup()` to simplify allocation and initialization of
 * the decimator context.
 * 
 * @par Scenario 1 - Direct Allocation
 * 
 * Depending on the structure and behavior of your application, you may be able
 * to directly (and statically) allocate the required memory in your application
 * source:
 * 
 * @code    
 *    // Mics: 2
 *    // Stage 2 filter: decimation factor 6; 65 taps
 *    // Framing: Enabled; 16 samples per frame
 *    // DC offset elimination: Enabled
 *    MA_STATE_DATA(2, 6, 65, 16, 1) ma_buffers;
 * @endcode
 * 
 * @par Scenario 2 - Type Definition
 * 
 * You may also separate the definition and allocation so the type can be used
 * independently from a particular instance:
 * 
 * @code
 *    // Define the type
 *    typedef MA_STATE_DATA(2, 6, 65, 16, 1) mic_array_buffers_t;
 *    // Allocate the buffers
 *    mic_array_buffers_t ma_buffers;
 *    mic_array_buffers_t* ma_buffers_p = &ma_buffers;
 * @endcode 
 * 
 * @par Scenario 3 - Multi-configuration
 * 
 * If your application requires run-time reconfiguration, you may want to have
 * two or more configurations that you wish to switch between:
 * 
 * @code
 *    typedef union {
 *      MA_STATE_DATA(1, 6, 65, 16, 1) config1; // 1 mic
 *      MA_STATE_DATA(2, 6, 65, 16, 1) config2; // 2 mics
 *    } mic_array_buffers_t;
 *    mic_array_buffers_t ma_buffers;
 * @endcode
 * 
 * @note Run-time reconfiguration is not yet supported.
 * 
 * @par Usage Example
 * 
 * A simple example of allocating these buffers and initializing a decimator
 * context may look as follows:
 * 
 * @code
 *    // stage1_coef, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT, 
 *    // stage2_coef and stage2_shr come from here.
 *    #include "mic_array/etc/filters_default.h"
 *    // ...
 *    #define MICS        2
 *    #define FRAME_SIZE  16
 *    #define USE_DCOE    1
 *    // ...
 *    // Allocate buffers
 *    static MA_STATE_DATA(MICS, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT,
 *                          FRAME_SIZE, USE_DCOE) ma_buffers;
 *    // Decimator context
 *    static ma_decimator_context_t dec_context;
 *    // ...
 *    void app_init() {
 *      // ...
 *      // Fully initialize decimator context
 *      ma_decimator_context_setup(&dec_context, &ma_buffers, MICS, stage1_coef,
 *            STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT, stage2_coef, stage2_shr,
 *            FRAME_SIZE, USE_DCOE);
 *      // ...
 *    }
 * @endcode
 * 
 * @par Notes
 * 
 * If framing is not used, specifying a `SAMPS_PER_FRAME` of `0` will avoid 
 * allocating unnecessary space.
 * 
 */
#define MA_STATE_DATA(MIC_COUNT, S2_DEC_FACTOR, S2_TAP_COUNT,                    \
                       SAMPS_PER_FRAME, USE_DC_ELIMINATION)                       \
struct {                                                                          \
  struct {                                                                        \
    uint32_t pdm_buffers[2][PDM_RX_BUFFER_SIZE_WORDS((MIC_COUNT),                 \
                                                     (S2_DEC_FACTOR))];           \
    uint32_t pdm_history[MA_PDM_HISTORY_SIZE_WORDS((MIC_COUNT))];                 \
  } stage1;                                                                       \
  struct {                                                                        \
    xs3_filter_fir_s32_t filters[(MIC_COUNT)];                                    \
    int32_t state_buffer[(MIC_COUNT)][(S2_TAP_COUNT)];                            \
  } stage2;                                                                       \
  struct {                                                                        \
    int32_t state_buffer[MA_FRAMING_BUFFER_SIZE((MIC_COUNT),                      \
                                                (SAMPS_PER_FRAME),                \
                                                (MA_FRAME_BUFF_COUNT_DEFAULT))];  \
  } framing;                                                                      \
  dcoe_chan_state_t dc_elim[(USE_DC_ELIMINATION)*(MIC_COUNT)];                    \
}        


/**
 * @brief Initialize a decimator context and its sub-components.
 * 
 * This macro meant as a convenience for app developers using the mic array
 * in a typical manner. It must only be used if the `MA_STATE_DATA()` macro was
 * used to allocate the buffers required by the decimator context and its 
 * sub-components.
 * 
 * This macro will fully initialize the decimator context as well as the second
 * stage decimation filters, framing (if enabled) component and DC offset
 * elimination filters (if enabled).
 * 
 * `CONTEXT` must be a pointer of type `ma_decimator_context_t*`. It is the 
 * decimator context to be initialized.
 * 
 * `MA_BUFFERS` must point to a struct allocated using the `MA_STATE_DATA()` 
 * macro. 
 * 
 * `MIC_COUNT` is the number of microphone channels to be captured by the 
 * decimator.
 * 
 * `S1_COEF` is a pointer to the first stage filter coefficient block. The first
 * stage filter has a fixed decimation factor of 32, and a fixed tap count of
 * 256. If the default first stage filter coefficients supplied with this 
 * library are to be used (see @ref `mic_array/etc/filters_default.h`), this
 * value should be `stage1_coef`.
 * 
 * `S2_DEC_FACTOR`, `S2_TAP_COUNT`, `S2_COEF` and `S2_SHR` are respectively the 
 * decimation factor, tap count, coefficients and output shift of the second
 * stage FIR filter. If the default secnd stage filter supplied with this 
 * library is to be used (see @ref `mic_array/etc/filters_default.h`), these
 * values should be `STAGE2_DEC_FACTOR`, `STAGE2_TAP_COUNT`, `stage2_coef`, and
 * `stage2_shr` respectively.
 * 
 * `SAMPS_PER_FRAME` is the frame size to be used. If this value is `0`, then
 * the framing component will be disabled, and each processed sample will be
 * transmitted by the decimator thread as it becomes available. If this value is
 * non-zero, the decimator will assemble processed samples into 
 * (non-overlapping) blocks of `SAMPS_PER_FRAME` samples (each sample being 
 * vector-valued with an element for each channel) called frames, and each frame
 * will be transmitted as it is completed.
 * 
 * `USE_DC_ELIMINATION` indicates whether the DC offset elimination filter 
 * should be applied to the output of the second stage filter. If this value is
 * `0`, DC offset elimination is disabled for all channels. Otherwise, it is
 * enabled for all channels.
 * 
 * @warning The values for `MIC_COUNT`, `S2_DEC_FACTOR`, `S2_TAP_COUNT`,
 * `SAMPS_PER_FRAME` and `USE_DC_ELIMINATION` _must match those supplied to 
 * `MA_STATE_DATA()`_ when `MA_BUFFERS` was allocated.
 * 
 * @param CONTEXT           Pointer to decimator context to be initialized.
 * @param MA_BUFFERS        Pointer to struct created using `MA_STATE_DATA()`.
 * @param MIC_COUNT         Number of microphone channels to be captured.
 * @param S1_COEF           Pointer to first stage filter coefficient block.
 * @param S2_DEC_FACTOR     Decimation factor of second stage filter.
 * @param S2_TAP_COUNT      Tap count of second stage filter.
 * @param S2_COEF           Pointer to coefficients of second stage filter.
 * @param S2_SHR            Arithmetic right-shift applied to second stage filter.
 * @param SAMPS_PER_FRAME     Number of samples per output frame.
 * @param USE_DC_ELIMINATION  Whether to enable DC offset elimination.
 */
#define ma_decimator_context_setup( CONTEXT, MA_BUFFERS, MIC_COUNT,               \
                                S1_COEF,                                          \
                                S2_DEC_FACTOR, S2_TAP_COUNT, S2_COEF, S2_SHR,     \
                                SAMPS_PER_FRAME, USE_DC_ELIMINATION  )            \
    do {                                                                          \
      ma_framing_context_t* framing = NULL;                                       \
      dcoe_chan_state_t* dcoe_states = NULL;                                      \
      if( SAMPS_PER_FRAME )                                                       \
        framing = (ma_framing_context_t*) &(MA_BUFFERS)->framing;                 \
      if( USE_DC_ELIMINATION )                                                    \
        dcoe_states = &(MA_BUFFERS)->dc_elim[0];                                  \
                                                                                  \
      ma_decimator_context_init((CONTEXT), (MIC_COUNT), (S2_DEC_FACTOR),          \
                                (S1_COEF), &(MA_BUFFERS)->stage1.pdm_history[0],  \
                                &(MA_BUFFERS)->stage2.filters[0], framing,        \
                                dcoe_states);                                     \
                                                                                  \
      if( USE_DC_ELIMINATION )                                                    \
        dcoe_state_init((CONTEXT)->dc_elim, (MIC_COUNT));                         \
                                                                                  \
      if( SAMPS_PER_FRAME )                                                       \
      ma_framing_init((CONTEXT)->framing, (MIC_COUNT), (SAMPS_PER_FRAME),         \
                      (MA_FRAME_BUFF_COUNT_DEFAULT));                             \
                                                                                  \
      for(int k = 0; k < (MIC_COUNT); k++){                                       \
        xs3_filter_fir_s32_init(&(MA_BUFFERS)->stage2.filters[k],                 \
                                &(MA_BUFFERS)->stage2.state_buffer[k][0],         \
                                (S2_TAP_COUNT), (S2_COEF), (S2_SHR));             \
      }                                                                           \
    } while(0)


#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__