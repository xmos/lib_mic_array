// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xs1.h>
#include <platform.h>
#include <stdint.h>

#include "app_config.h"
#include "xmath/xmath.h"
#include "xcore/parallel.h"
#include "mic_array/etc/fir_1x16_bit.h"

#ifndef NUM_DECIMATOR_SUBTASKS
#error Please set NUM_DECIMATOR_SUBTASKS
#endif

DECLARE_JOB(decimator_subtask, (
  unsigned, unsigned, const unsigned,
  uint32_t*, const uint32_t*,
  const unsigned, filter_fir_s32_t*,
  uint32_t*, int32_t*));

static inline void shift_buffer(uint32_t* buff);

void decimator_subtask_run(const unsigned num_mics,
        uint32_t* s1_hist, const uint32_t* s1_filter_coef,
        const unsigned s2_dec_factor, filter_fir_s32_t* s2_filters,
        uint32_t* pdm_block, int32_t* sample_out)
{
#if NUM_DECIMATOR_SUBTASKS <= 1
  decimator_subtask(0, NUM_DECIMATOR_SUBTASKS, num_mics,
                    s1_hist, s1_filter_coef,
                    s2_dec_factor, s2_filters,
                    pdm_block, sample_out);
#elif NUM_DECIMATOR_SUBTASKS > 1
  PAR_JOBS (
    PJOB(decimator_subtask, (0, NUM_DECIMATOR_SUBTASKS, num_mics,
                             s1_hist, s1_filter_coef,
                             s2_dec_factor, s2_filters,
                             pdm_block, sample_out)),
    PJOB(decimator_subtask, (1, NUM_DECIMATOR_SUBTASKS, num_mics,
                             s1_hist, s1_filter_coef,
                             s2_dec_factor, s2_filters,
                             pdm_block, sample_out))
#if NUM_DECIMATOR_SUBTASKS > 2
    ,PJOB(decimator_subtask, (2, NUM_DECIMATOR_SUBTASKS, num_mics,
                             s1_hist, s1_filter_coef,
                             s2_dec_factor, s2_filters,
                             pdm_block, sample_out))
#endif
#if NUM_DECIMATOR_SUBTASKS > 3
    ,PJOB(decimator_subtask, (3, NUM_DECIMATOR_SUBTASKS, num_mics,
                             s1_hist, s1_filter_coef,
                             s2_dec_factor, s2_filters,
                             pdm_block, sample_out))
#endif
#if NUM_DECIMATOR_SUBTASKS > 4
  #error "NUM_DECIMATOR_SUBTASKS: Value not supported"
#endif
  );
#endif
}

/**
 * @brief The common subtask decimation routine.
 *
 * @param mic_start_index The first mic to process in the task.
 * @param mic_increment_index The number of indicies in the mic array to increment by.
 * @param mic_count The total number of microphones in the array to be processed by the subtask(s).
 * @param s1_hist Stage 1 PDM history.
 * @param s1_filter_coef State 1 filter coefficients.
 * @param s2_dec_factor Stage 2 decimation factor.
 * @param s2_filters Stage 2 FIR filters.
 * @param pdm_block PDM data to be processed.
 * @param sample_out Output sample vector.
 */
void decimator_subtask(
        unsigned mic_start_index, unsigned mic_increment_index, const unsigned mic_count,
        uint32_t* s1_hist, const uint32_t* s1_filter_coef,
        const unsigned s2_dec_factor, filter_fir_s32_t* s2_filters,
        uint32_t* pdm_block, int32_t* sample_out)
{
  uint32_t (*pdm_data)[s2_dec_factor] = (uint32_t (*)[s2_dec_factor]) pdm_block;

  for (unsigned mic = mic_start_index; mic < mic_count; mic += mic_increment_index) {
    const unsigned pdm_history_elems_per_mic = 8; // See "pdm_history" in decimator class template
    uint32_t* hist = &s1_hist[mic * pdm_history_elems_per_mic];

    for (unsigned k = 0; k < s2_dec_factor; k++) {
      hist[0] = pdm_data[mic][k];
      int32_t streamA_sample = fir_1x16_bit(hist, s1_filter_coef);
      shift_buffer(hist);

      if (k < (s2_dec_factor - 1)) {
        filter_fir_s32_add_sample(&s2_filters[mic], streamA_sample);
      } else {
        sample_out[mic] = filter_fir_s32(&s2_filters[mic], streamA_sample);
      }
    }
  }
}

/**
 * @brief Rotate 8-word buffer 1 word up.
 *
 * Each word `buff[k]` is moved to `buff[(k+1)%8]`.
 *
 * @param buff  Word buffer to be rotated.
 */
static inline
void shift_buffer(uint32_t* buff)
{
  uint32_t* src = &buff[-1];
  asm volatile("vldd %0[0]; vstd %1[0];" :: "r"(src), "r"(buff) : "memory" );
}
