#pragma once

#include <stdint.h>

#ifdef __XC__
extern "C" {
#endif

/**
 * @brief DC Offset Elimination State
 * 
 * This is the required state information for a single channel to which the DC
 * offset elimination filter is being applied.
 * 
 * To apply the DC offset elimination filter to multiple channels simultaneously,
 * an array of `dcoe_chan_state_t` should be used.
 * 
 * `dcoe_state_init()` is used to initialize an array of state objects,
 * and `dcoe_filter()` is used at each time step to apply
 * the filter and get the resulting output sample.
 * 
 * As DC offset elimination is an IIR filter, this state must persist between
 * time steps.
 * 
 * @par Use With Decimator
 * 
 * If the decimator task (`ma_decimator_task()` supplied in this library is used 
 * for processing a PDM audio stream, the decimator context 
 * (`ma_decimator_context_t`) keeps a pointer to an array of `dcoe_chan_state_t`
 * containing this state.
 * 
 * If the `MA_STATE_DATA()` macro is used, space is allocated for the DC offset 
 * elimination state for each channel.
 * 
 * If the `ma_decimator_context_setup()` macro is used to initialize the decimator 
 * context, the allocated state buffers will be initialized and connected to the 
 * context.
 * 
 */
typedef struct {
  /** Previous output sample value.  */
  int64_t prev_y;
} dcoe_chan_state_t;


/**
 * Initialize the DC offset elimination state.
 * 
 * The DC offset elimination state needs to be intialized before starting the 
 * decimator.
 * 
 * The state vector `state` must persist between audio samples and is supplied
 * to each call to `dcoe_filter()`.
 * 
 * @param[in] state       Array of dcoe_chan_state_t to be initialized.
 * @param[in] chan_count  Number of elements in `state`.
 */
void dcoe_state_init(
    dcoe_chan_state_t state[],
    const unsigned chan_count);


/**
 * Update the DC offset elimination state with a new input sample and get 
 * a new output sample.
 * 
 * To use DC offset elimination on a signal, this function should be called 
 * once per sample (a sample being a vector which contains one value for each 
 * audio channel) of that stream.
 * 
 * The index of each array (`state`, `new_input` and `new_output`) corresponds
 * to the audio channel. The update associated with each audio channel is 
 * independent of the other audio channels.
 * 
 * The update equation used for each channel is:
 * 
 * @code
 *   y[t] = R * y[t-1] + x[t] - x[t-1]
 * @endcode
 * 
 * where `t` is the current sample time index, `y[]` is the output signal and
 * `x[]` is the input signal.
 * 
 * @param[out]  new_output  Array into which the output sample will be placed.
 * @param[in]   state       DC offset elimination state vector.
 * @param[in]   new_input   New input sample.
 * @param[in]   chan_count  Number of channels to be processed.
 */
void dcoe_filter(
    int32_t new_output[],
    dcoe_chan_state_t state[],
    int32_t new_input[],
    const unsigned chan_count);
  
#ifdef __XC__
}
#endif