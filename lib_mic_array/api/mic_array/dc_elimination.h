// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "api.h"
#include <stdint.h>

C_API_START

/**
 * @brief DC Offset Elimination (DCOE) State
 * 
 * This is the required state information for a single channel to which the DC
 * offset elimination filter is to be applied.
 * 
 * To apply the DC offset elimination filter to multiple channels 
 * simultaneously, an array of `dcoe_chan_state_t` should be used.
 * 
 * `dcoe_state_init()` is used once to initialize an array of state objects, and
 * `dcoe_filter()` is used on each consecutive sample to apply the filter and
 * get the resulting output sample.
 * 
 * DC offset elimination is an IIR filter. The state must persist between time
 * steps.
 * 
 * @par Use in lib_mic_array
 * @parblock
 * Typical users of lib_mic_array will not need to directly use this type or any
 * functions which take it as a parameter.
 * 
 * The C++ class template `mic_array::DcoeSampleFilter`, if used in an
 * application's mic array unit, will allocate, initialize and apply the DCOE
 * filter automatically.
 * @endparblock
 * 
 * @par With MicArray Prefabs
 * @parblock
 * The MicArray prefab `mic_array::prefab::BasicMicArray` has a `bool` template
 * parameter `USE_DCOE` which indicates whether the
 * `mic_array::DcoeSampleFilter` should be used. If `true`, DCOE will be
 * enabled.
 * @endparblock
 * 
 * @par With Vanilla API
 * @parblock
 * When using the 'vanilla' API, DCOE is enabled by default. To disable DCOE
 * when using this API, add a preprocessor definition to the compiler flags,
 * setting `MIC_ARRAY_CONFIG_USE_DC_ELIMINATION` to `0`.
 * @endparblock
 */
MA_C_API
typedef struct {
  /** Previous output sample value.  */
  int64_t prev_y;
} dcoe_chan_state_t;


/**
 * @brief Initialize DCOE states.
 * 
 * The DC offset elimination state needs to be intialized before the filter can
 * be applied. This function initializes it.
 * 
 * For correct behavior, the state vector `state` must persist between audio 
 * samples and is supplied with each call to `dcoe_filter()`.
 * 
 * @param[in] state       Array of `dcoe_chan_state_t` to be initialized.
 * @param[in] chan_count  Number of elements in `state`.
 */
MA_C_API
void dcoe_state_init(
    dcoe_chan_state_t state[],
    const unsigned chan_count);


/**
 * @brief Apply DCOE filter.
 * 
 * Applies the DC offset elimination filter to get a new output sample and 
 * updates the filter state.
 * 
 * For correct behavior, this function should be called once per sample (here
 * "sample" refers to a vector-valued quantity containing one element for each
 * audio channel) of that stream.
 * 
 * The index of each array (`state`, `new_input` and `new_output`) corresponds
 * to the audio channel. The update associated with each audio channel is 
 * independent of each other audio channel.
 * 
 * The equation used for each channel is:
 * 
 * @code
 *   y[t] = R * y[t-1] + x[t] - x[t-1]
 * @endcode
 * 
 * where `t` is the current sample time index, `y[]` is the output signal, `x[]`
 * is the input signal, and `R` is `(252.0/256)`.
 * 
 * To filter a sample in-place use the same array for both the `new_input` and
 * `new_output` arguments.
 * 
 * @param[out]  new_output  Array into which the output sample will be placed.
 * @param[in]   state       DC offset elimination state vector.
 * @param[in]   new_input   New input sample.
 * @param[in]   chan_count  Number of channels to be processed.
 */
MA_C_API
void dcoe_filter(
    int32_t new_output[],
    dcoe_chan_state_t state[],
    int32_t new_input[],
    const unsigned chan_count);
  
C_API_END