// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

#include "xs1.h"

/*  

  File contains the ISR logic for capturing PDM samples coming in.

*/



.section .dp.data, "awd", @progbits

.align 8
pdm_rx_context:
.L_port:          .word 0
.L_buffA:         .word 0
.L_buffB:         .word 0
.L_phase1:        .word 0
.L_phase1_reset:  .word 0
.L_c_out:         .word 0
.L_c_in:          .word 0

.global pdm_rx_context


#define NSTACKWORDS     4


.text
.issue_mode single
.align 16         // 16-byte alignment guarantees that FNOPs always happen in the same spots

#define A   r4
#define B   r5
#define C   r6
#define D   r7

.cc_top pdm_rx_isr.function,pdm_rx_isr

pdm_rx_isr:

    extsp 4
    stw r4, sp[0]
    stw r5, sp[1]
    stw r6, sp[2]
    stw r7, sp[3]
    // std r4, r5, sp[0]
    // std r6, r7, sp[1]
    ldw A, dp[.L_port]
    in A, res[A]
    ldw D, dp[.L_buffA]
    ldw C, dp[.L_phase1]
    stw A, D[C]
    bf C, .L_emit
    sub C, C, 1
    stw C, dp[.L_phase1]
    // ldd r6, r7, sp[1] 
    // ldd r4, r5, sp[0]
    ldw r4, sp[0]
    ldw r5, sp[1]
    ldw r6, sp[2]
    ldw r7, sp[3]
    ldaw sp, sp[NSTACKWORDS]
    kret

  .L_emit:

  // Reset phase1 number
    ldw A, dp[.L_phase1_reset]
    stw A, dp[.L_phase1]

  // Swap PDM buffers A and B
    ldw A, dp[.L_buffB]
    stw A, dp[.L_buffA]
    stw D, dp[.L_buffB]

  // Signal that the next set of samples is ready, which will be those in PDM buffer B
  // the channel output should be non-blocking because it's only a word
    ldw A, dp[.L_c_out]
    out res[A], D

  // And we're done
    ldw r4, sp[0]
    ldw r5, sp[1]
    ldw r6, sp[2]
    ldw r7, sp[3]
    // ldd r6, r7, sp[1] 
    // ldd r4, r5, sp[0]
    ldaw sp, sp[NSTACKWORDS]
    kret


.L_func_end:
.cc_bottom pdm_rx_isr.function

.global pdm_rx_isr
// .type pdm_rx_isr,@function

// .size pdm_rx_isr, .L_func_end - pdm_rx_isr

#endif //defined(__XS3A__)


