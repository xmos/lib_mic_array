// Copyright 2021-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

/*  

  File contains the ISR logic for capturing PDM samples coming in.

*/



.section .dp.data, "awd", @progbits

.align 8
pdm_rx_isr_context:
.L_port:            .word 0
.L_buffA:           .word 0
.L_buffB:           .word 0
.L_phase1:          .word 0
.L_phase1_reset:    .word 0
.L_c_out:           .word 0
.L_credit:          .word 0
.L_missed_blocks:   .word -1

.global pdm_rx_isr_context


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
    stw r4, sp[0];    stw r5, sp[1]
    stw r6, sp[2];    stw r7, sp[3]
  // Read port data
    ldw A, dp[.L_port]
    in A, res[A]
  // Place in PDM buffer
    ldw D, dp[.L_buffA]
    ldw C, dp[.L_phase1]
    stw A, D[C]
  // If full, emit the buffer
    bf C, .L_emit
  // Decrement phase and return
    sub C, C, 1
    stw C, dp[.L_phase1]
    ldw r4, sp[0];    ldw r5, sp[1]
    ldw r6, sp[2];    ldw r7, sp[3]
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
  // Next set of samples is ready.

  // Check if there is currently send credit, and if not, quietly drop the
  // pdm block. This prevents a possible deadlock if the main thread gets
  // backed up.
    ldw A, dp[.L_credit]
    bt A, .L_has_credit
  .L_no_credit:
    // No credit. increment the missed block counter.
    ldw A, dp[.L_missed_blocks]
    not D, A  // if the missed blocks counter is set to -1 (default)
    ecallf D  // then dropping a block is a crashable offense
    add A, A, 1
    stw A, dp[.L_missed_blocks]
    bu .L_finish
  .L_has_credit:
    sub A, A, 1
    stw A, dp[.L_credit]

    ldw A, dp[.L_c_out]
    out res[A], D
  
  .L_finish:
  // And we're done
    ldw r4, sp[0];    ldw r5, sp[1]
    ldw r6, sp[2];    ldw r7, sp[3]
    ldaw sp, sp[NSTACKWORDS]
    kret
.L_func_end:
.cc_bottom pdm_rx_isr.function

.global pdm_rx_isr

#endif //defined(__XS3A__)


