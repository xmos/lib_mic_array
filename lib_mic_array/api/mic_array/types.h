#pragma once

// Some types are defined here to avoid circular header dependencies.


#include "etc/xcore_compat.h"

#ifdef __XC__
extern "C" {
#endif


/**
 * @brief Type of application context used for data output in the decimator
 *        thread.
 * 
 * `ma_proc_sample_ctx_t` is the type for the application context in the 
 * decimator thread. Its default value is `chanend_t`.
 * 
 * The default behavior for the decimator thread is to accept a `chanend_t` as
 * a parameter, and as processed samples or frames become ready for subsequent
 * processing stages, that chanend is used to transfer the audio data to the
 * following stage (via `ma_frame_tx_s32()`).
 * 
 * In some use cases, an alternative behavior may be preferred. For example, a
 * FreeRTOS-based application may want to use FreeRTOS queues to transfer audio
 * data between threads. In that case, the application developer may wish to
 * override this type with a handle for a FreeRTOS queue.
 * 
 * As another example, an application may wish to send the audio data dupicated 
 * to two different threads (perhaps one is for a terminal stage looking for
 * keyword detection events and the other is for the main audio processing 
 * pipeline). In is case, the application developer may wish to replace this
 * type with an array of channels.
 * 
 * To override this parameter, in your build files, add a compile definition for 
 * the lib_mic_array library such as `-DMA_PROC_SAMPLE_CONTEXT_TYPE=your_type_t`.
 * 
 * If this parameter is overridden, the application must also override the 
 * implementation of `ma_proc_frame()` to use the user-defined type.
 * 
 * Note that the default for `MA_PROC_FRAME_CONTEXT_TYPE` (and thus for
 * `ma_proc_frame_ctx_t`) is `ma_proc_sample_ctx_t`. So if 
 * `MA_PROC_SAMPLE_CONTEXT_TYPE` is overridden, `MA_PROC_FRAME_CONTEXT_TYPE` may
 * also need to be overriden if framing is used, or else `ma_proc_frame()` may
 * need to be overridden.
 */
#ifndef MA_PROC_SAMPLE_CONTEXT_TYPE
#define MA_PROC_SAMPLE_CONTEXT_TYPE  chanend_t
#endif

/**
 * @brief Decimator application context type for sample processing.
 * 
 * The underlying content of a `ma_proc_sample_ctx_t` is opaque to the decimator
 * itself, but is passed along to `ma_proc_sample()` as its application context.
 * 
 * The provided implementation of `ma_proc_sample()` expects a `chanend_t` over
 * which to transmit completed frames or samples.
 * 
 * If `MA_PROC_SAMPLE_CONTEXT_TYPE` is overridden by an application, custom
 * implementations of `ma_proc_sample()` and/or `ma_proc_frame()` may be 
 * required.
 */
typedef MA_PROC_SAMPLE_CONTEXT_TYPE ma_proc_sample_ctx_t;



/**
 * @brief `ma_proc_frame()` application context type.
 * 
 * See `MA_PROC_SAMPLE_CONTEXT_TYPE` above. These two types are closely related
 * but defined separately to allow for flexibility if needed.
 */
#ifndef MA_PROC_FRAME_CONTEXT_TYPE
#define MA_PROC_FRAME_CONTEXT_TYPE  ma_proc_sample_ctx_t
#endif

/**
 * @brief Decimator application context type for frame processing.
 * 
 * The underlying content of a `ma_proc_frame_ctx_t` is opaque to the decimator
 * itself, but is passed along to `ma_proc_frame()` as its application context.
 * 
 * The provided implementation of `ma_proc_frame()` expects a `chanend_t` over
 * which to transmit completed frames or samples.
 * 
 * If `MA_PROC_FRAME_CONTEXT_TYPE` is overridden by an application, a custom
 * implementations of `ma_proc_frame()` may be required.
 */
typedef MA_PROC_FRAME_CONTEXT_TYPE ma_proc_frame_ctx_t;


#ifdef __XC__
}
#endif //__XC__