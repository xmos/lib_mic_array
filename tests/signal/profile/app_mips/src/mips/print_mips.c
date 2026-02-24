// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>

#include <xcore/hwtimer.h>

#include "app_config.h"

#include "mips.h"
#include "mic_array.h"

static inline
void hwtimer_delay_seconds(unsigned delay) {
  hwtimer_t tmr = hwtimer_alloc();
  hwtimer_delay(tmr, delay * XS1_TIMER_HZ);
  hwtimer_free(tmr);
}

void print_mips(const unsigned use_pdm_rx_isr)
{

  while(1){
    hwtimer_delay_seconds(1);

    uint64_t t = tick_count;
    uint64_t c = inst_count;

    const float usec = t / 100.0f;  // microseconds since the count started
    const float ipus = c / usec;    // instructions per microsecond
    const float mips = ipus;        // million instructions per second
    unsigned burns = (use_pdm_rx_isr)? 6 : 5;

    const float ma_mips = 600 - burns*mips;

    printf(" mic_array: %0.04f MIPS\n", ma_mips);
  }
}

// Notes
// -----
//  million instructions per second = million instructions per million microseconds
//  million instructions per second = instructions per microsecond
//  6 threads using [mips] MIPS, and one thread (mic array) using [ma_mips] MIPS
//  600 = 6*mips + ma_mips -->  ma_mips = 600 - 6*mips
