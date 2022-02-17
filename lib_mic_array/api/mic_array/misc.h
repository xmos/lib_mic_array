#pragma once

#include "mic_array/framing.h"

#include <stdint.h>


#ifdef __XC__
extern "C" {
#endif


#ifndef MA_FRAME_BUFF_COUNT_DEFAULT
#define MA_FRAME_BUFF_COUNT_DEFAULT   2
#endif

/**
 * Several components of lib_mic_array require buffers to be supplied whose 
 * size depends upon application parameters. Rather than requiring applications
 * to `#define` macros indicating e.g. the number of microphones and the stage
 * 2 decimation factor (and preventing run-time reconfiguration), this macro 
 * is provided to simplify configuration.
 * 
 * @par Scenario 1
 * 
 * Depending on the structure and behavior of your application, you may be able
 * to directly (and statically) allocate the required memory:
 * 
 *     MIC_ARRAY_DATA(2, 6, 65, 16, 2) ma_buffers;
 * 
 * @par Scenario 2
 * 
 * You may also separate the definition and allocation so the type can be used
 * independently from a particular instance:
 * 
 *     typedef MIC_ARRAY_DATA(2, 6, 65, 16, 2) mic_array_buffers_t;
 *     mic_array_buffers_t ma_buffers;
 *     mic_array_buffers_t* ma_buffers_p = &ma_buffers;
 *     // etc
 * 
 * @par Scenario 3
 * 
 * If your application requires run-time reconfiguration, you may want to have
 * two or more configurations that you wish to switch between:
 * 
 *     typedef union {
 *      MIC_ARRAY_DATA(1, 6, 65, 16, 2) config1; // 1 mic
 *      MIC_ARRAY_DATA(2, 6, 65, 16, 2) config2; // 2 mics
 *     } mic_array_buffers_t;
 *     mic_array_buffers_t ma_buffers;
 * 
 * @par Using This Struct
 * 
 * @todo Show how this actually gets used
 * 
 * @par Notes
 * 
 * If framing is not used, specifying a `SAMPS_PER_FRAME` of `0` will avoid 
 * allocating unnecessary space.
 * 
 */
#define MIC_ARRAY_DATA(MIC_COUNT, S2_DEC_FACTOR, S2_TAP_COUNT,                    \
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
  ma_dc_elim_chan_state_t dc_elim[(USE_DC_ELIMINATION)*(MIC_COUNT)];              \
}                                       


/**
 * Unfortunately has to be implemented as a macro because MA_BUFFERS doesn't have
 * a defined type (though the tree of fields is known).
 */
#define mic_array_context_init( CONTEXT, MA_BUFFERS, MIC_COUNT,                   \
                                S1_COEF,                                          \
                                S2_DEC_FACTOR, S2_TAP_COUNT, S2_COEF, S2_SHR,     \
                                SAMPS_PER_FRAME, USE_DC_ELIMINATION  )            \
    do {                                                                          \
      (CONTEXT)->mic_count = (MIC_COUNT);                                         \
                                                                                  \
      (CONTEXT)->stage1.filter_coef = (uint32_t*) (S1_COEF);                      \
      (CONTEXT)->stage1.pdm_history = &(MA_BUFFERS)->stage1.pdm_history[0];       \
                                                                                  \
      (CONTEXT)->stage2.decimation_factor = (S2_DEC_FACTOR);                      \
      (CONTEXT)->stage2.filters = &(MA_BUFFERS)->stage2.filters[0];               \
                                                                                  \
      (CONTEXT)->framing = NULL;                                                  \
      if( SAMPS_PER_FRAME ) (CONTEXT)->framing = (ma_framing_context_t*)          \
                                            &(MA_BUFFERS)->framing;               \
                                                                                  \
      (CONTEXT)->dc_elim = NULL;                                                  \
      if( USE_DC_ELIMINATION ) (CONTEXT)->dc_elim = &(MA_BUFFERS)->dc_elim[0];    \
                                                                                  \
      ma_dc_elimination_init((CONTEXT)->dc_elim, (MIC_COUNT));                    \
                                                                                  \
      ma_framing_init((CONTEXT)->framing, (MIC_COUNT), (SAMPS_PER_FRAME),         \
                      (MA_FRAME_BUFF_COUNT_DEFAULT));                             \
                                                                                  \
      for(int k = 0; k < MIC_COUNT; k++){                                         \
        xs3_filter_fir_s32_init(&(MA_BUFFERS)->stage2.filters[k],                 \
                                &(MA_BUFFERS)->stage2.state_buffer[k][0],         \
                                (S2_TAP_COUNT), (S2_COEF), (S2_SHR));             \
      }                                                                           \
    } while(0)


/**
 * The required state information for a channel using DC offset elimination.
 */
typedef struct {
  int64_t prev_y;
} ma_dc_elim_chan_state_t;


void ma_dc_elimination_init(
    ma_dc_elim_chan_state_t state[],
    const unsigned chan_count);


void ma_dc_elimination_next_sample(
    int32_t new_output[],
    ma_dc_elim_chan_state_t state[],
    int32_t new_input[],
    const unsigned chan_count);
  
#ifdef __XC__
}
#endif