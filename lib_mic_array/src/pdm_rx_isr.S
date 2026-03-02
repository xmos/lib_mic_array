// Copyright 2021-2026 XMOS LIMITED.
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
    // Undo swap if no credit, to avoid writing to a buffer that is potentially simultaneously being read.
    // Since we check for credits after writing to the buffer, the number of available buffers need to be one more than the
    // max allowed credits, so the last buffer written to before realising that we're out of credits can be used
    // for writing subsequent blocks (no credit no swap) and what's already sent over the channel doesn't get tampered with.
    ldw A, dp[.L_buffA]
    stw A, dp[.L_buffB]
    stw D, dp[.L_buffA]
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

#if defined(__VX4A__) || defined(__VX4B__)

//TODO: This function is not verified. 

#define STRUCT_NAME   pdm_rx_isr_context
#define FUNCTION_NAME pdm_rx_isr
#define NSTACK_WORDS  8 
#define NSTACK_BYTES  (NSTACK_WORDS*4)

.section .data.STRUCT_NAME, "aw"
.p2align 1
.globl STRUCT_NAME
STRUCT_NAME:
  .word  0 // .L_port
  .word  0 // .L_buffA
  .word  0 // .L_buffB
  .word  0 // .L_phase1
  .word  0 // .L_phase1_reset
  .word  0 // .L_c_out
  .word  0 // .L_credit
  .word -1 // .L_missed_blocks

.section .text
.p2align 4
.globl FUNCTION_NAME
.type FUNCTION_NAME,@function
FUNCTION_NAME:
    unimp //TODO - this function is not verified and may contain errors, so prevent it from being accidentally used without review
    addi sp, sp, -16
    sw   s2, 0(sp)
    sw   s3, 4(sp)
    sw   s4, 8(sp)
    sw   s5, 12(sp)

    // Load base address of context
    la   s0, pdm_rx_isr_context

    // Read PDM port (offset 0)
    lw   s2, 0(s0)
    xm.in s2, s2

    // Store sample into active buffer
    lw   s5, 4(s0)          // .L_buffA at offset 4
    lw   s4, 12(s0)         // .L_phase1 at offset 12
    xm.stw s2, s4(s5)

    // Emit buffer if phase reached zero
    beqz s4, .L_emit

    // Decrement phase counter
    addi s4, s4, -1
    sw   s4, 12(s0)         // Store back to .L_phase1

    // Restore context and return
    lw   s2, 0(sp)
    lw   s3, 4(sp)
    lw   s4, 8(sp)
    lw   s5, 12(sp)
    addi sp, sp, 16
    csrr t5, xm.smtval
    csrw mtval, t5
    mret

.L_emit:
    // Reset phase counter
    lw   s2, 16(s0)         // .L_phase1_reset at offset 16
    sw   s2, 12(s0)         // Store to .L_phase1

    // Swap PDM buffers
    lw   s2, 8(s0)          // .L_buffB at offset 8
    sw   s2, 4(s0)          // Store to .L_buffA
    sw   s5, 8(s0)          // Store to .L_buffB

    // Check transmit credit
    lw   s2, 24(s0)         // .L_credit at offset 24
    bnez s2, .L_has_credit

.L_no_credit:
    // Undo buffer swap
    lw   s2, 4(s0)          // .L_buffA
    sw   s2, 8(s0)          // .L_buffB
    lw   s2, 8(s0)          // restored .L_buffB
    sw   s2, 4(s0)          // .L_buffA

    // Increment missed block counter
    lw   s2, 28(s0)         // .L_missed_blocks at offset 28
    xm.not    s5, s2
    xm.assert s5
    addi s2, s2, 1
    sw   s2, 28(s0)
    tail .L_finish

.L_has_credit:
    // Consume credit and send buffer
    addi s2, s2, -1
    sw   s2, 24(s0)         // Store back to .L_credit
    lw   s2, 20(s0)         // .L_c_out at offset 20
    xm.out s2, s5

.L_finish:
    // Restore context and exit ISR
    lw   s2, 0(sp)
    lw   s3, 4(sp)
    lw   s4, 8(sp)
    lw   s5, 12(sp)
    addi sp, sp, 16
    csrr t5, xm.smtval
    csrw mtval, t5
    mret

.L_func_end:

.size FUNCTION_NAME, . -FUNCTION_NAME
.resource_const FUNCTION_NAME, "stack_frame_bytes", NSTACK_BYTES
.resource_list_empty FUNCTION_NAME, "callees"
.resource_list_empty FUNCTION_NAME, "tail_callees"
.resource_list_empty FUNCTION_NAME, "parallel_callees"


#endif // __VX4A__ || __VX4B__
