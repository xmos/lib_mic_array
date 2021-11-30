// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

#include "xs1.h"

/*  

  File contains the ISR logic for capturing PDM samples coming in.
  

  For the layout (and descriptions) of the stack used in this ISR, see the struct 
  `pdm_rx_workspace` in pdm_rx.c.

  NOTE: these likely need to be rearranged to optimize access, but I'll deal with that later.

*/

#define N_MICS            (2)
#define PDM_COEF_BLOCKS   (1)

#define FUNCTION_NAME   pdm_rx_isr

#define STK_SSP         0
#define STK_SPC         1
#define STK_SSR         2
#define STK_SED         3
#define STK_ET          4
#define STK_DP          5
#define STK_CP          6
#define STK_LR          7

#define STKD_R0R1       4   // 8,9
#define STKD_R2R3       5   // ...
#define STKD_R4R5       6   
#define STKD_R6R7       7   
#define STKD_R8R9       8   
#define STKD_R10R11     9   // 18,19


#define STK_VR          20
#define STK_VD          28
#define STK_VC          36
#define STK_VCTRL       44

#define STK_CTX_END     44

#define STK_PHASE1      (STK_CTX_END+1)
#define STK_PHASE2      (STK_CTX_END+2)
#define STK_PORT        (STK_CTX_END+3)
#define STK_FIR_COEF    (STK_CTX_END+4)
#define STK_PDM_BUFF    (STK_CTX_END+5)
#define STK_STG2_DEC    (STK_CTX_END+6)
#define STK_PCM_VECT    (STK_CTX_END+7)




.text
.issue_mode single
.align 16

// with 2 mics and a 120 MIPS core, the ISR *must* be fewer than 625 instructions or it isn't keeping up.


#define A   r4
#define B   r5
#define C   r6
#define D   r7



.cc_top FUNCTION_NAME.function,FUNCTION_NAME
FUNCTION_NAME: 
  kentsp 0
  std r4, r5, sp[STKD_R4R5]
  std r6, r7, sp[STKD_R6R7]

  // astew: Seems like there might be some advantage to doing this bit in dual-issue mode...
  //        but the extra instructions to make it dual-issue seem to cancel out the advantage
  //        that I'm able to find.  How could this be done differently to make dual-issue work
  //        better?

  ldw A, sp[STK_PORT]
  in A, res[A]
  // Now we have 16 samples for each mic, interleaved bit by bit

  // unzip to separate them
  ldc B, 0
  unzip B, A, 0

  // put them in the buffer where appropriate

  ldw C, sp[STK_PHASE1]
  ldw D, sp[STK_PDM_BUFF]

  st16 A, D[C]   // Mic 1    (TODO: check whether I've unzipped appropriately)
  ldaw D, D[8]   // TODO: if more than one block is used in the PDM->PCM decimation filter,
                 //       this will be wrong.
  st16 B, D[C]   // Mic 2
  add C, C, 1
  zext C, 1
  stw C, sp[STK_PHASE1]

  // ldc B, 16
  // ldw A, dp[pdm_sample_count]
  // add A, A, B
  // stw A, dp[pdm_sample_count]

  // If the phase is nonzero, we're done for now
  bf C, .L_decimate
  
  ldd r6, r7, sp[STKD_R6R7]
  ldd r4, r5, sp[STKD_R4R5]
  krestsp 0
  kret

  .L_decimate:

  // Phase is 0, that means we've filled up the sample buffers and it's time to do some decimation.
  // Here we should save the rest of the caller's thread state
  
  std r0, r1, sp[STKD_R0R1]
  std r2, r3, sp[STKD_R2R3]
  std r8, r9, sp[STKD_R8R9]
  std r11, r10, sp[STKD_R10R11]

#define E   r8
#define F   r9

  ldw D, sp[STK_PDM_BUFF]
  ldc C, N_MICS
  ldw B, sp[STK_PCM_VECT]

  // E <-- Current phase2 value
  ldw E, sp[STK_PHASE2]

  // F <-- stage 2 decimation factor
  // The PCM sample vector has shape int32[N_MICS][STG2_DEC_FACTOR]
  ldw F, sp[STK_STG2_DEC]


  .L_pdm_to_pcm_loop_top:
    mov r0, D
    ldw r1, sp[STK_FIR_COEF]
    ldc r2, PDM_COEF_BLOCKS
    
    bl fir_1x16_bit

    //r0 now has the 32-bit result. Put it in the PCM vector
    stw r0, B[E]
    add E, E, F

    ldaw D, D[8] // TODO: with more than one stage1 filter block, this is wrong
    sub C, C, 1
    bt C, .L_pdm_to_pcm_loop_top
  .L_pdm_to_pcm_loop_bot:

  // Now we should shift each channel's PDM buffer up one word
  // This can be easily accomplished using the VPU with a VLMACCR 
  // in 32-bit mode. This op is circular, but we don't care what
  // ends up in the first word.

  ldc C, N_MICS
  ldc r11, 0
  vsetc r11
  ldw r11, sp[STK_PDM_BUFF]

  .L_pdm_shift_loop_top:

    vldr r11[0]
    vlmaccr r11[0]
    vstr r11[0]
    ldaw r11, r11[8]
    sub C, C, 1
    bt C, .L_pdm_shift_loop_top

  .L_pdm_shift_loop_bot:

  // Increment phase2, and if it's greater than the decimation factor, we'll need to 
  // perform a context switch and call proc_pcm().
  // If E<F, we can just reload the stored registers.
  ldw E, sp[STK_PHASE2]
  add E, E, 1
  eq r0, E, F
  mul F, F, r0
  sub E, E, F
  stw E, sp[STK_PHASE2]

  bf r0, .L_finish_isr

  
  // Okay, now we have to force a context switch for the thread that was interrupted.
  //  - save the rest of the interrupted thread's state into the workspace,
  //  - set this thread's registers (specifically, the SP and PC we'll be returning
  //      to when this ISR completes) to call the PCM decimator function
  //  - when that completes, restore the original interrupted thread's state

  // Save the SPC, SSR, SED, ET
  stw spc, sp[STK_SPC]
  stw ssr, sp[STK_SSR]
  stw sed, sp[STK_SED]
  stw et, sp[STK_ET]

  // Save DP, CP, LR, vector regs
  stw dp, sp[STK_DP]
  stw cp, sp[STK_CP]
  stw lr, sp[STK_LR]


  vgetc r11
  stw r11, sp[STK_VCTRL]
  ldaw r11, sp[STK_VR]
  vstr r11[0]
  ldaw r11, sp[STK_VD]
  vstd r11[0]
  ldaw r11, sp[STK_VC]
  vstc r11[0]

  // Now we want to call proc_pcm(). 

  ldw r0, sp[STK_PCM_VECT]
  extsp 4 // NOTE: Be careful with the STK_* defines in here
  ldap r11, .L_outside_kernel

  // NOTE: I THINK I"M DOING SOMETHING WRONG HERE. MAYBE I JUST GOT TO SET SSR TO
  //       THE RIGHT THING BEFORE CALLING KRET?

  ldc r11, 0x02  // enable interrupts when we kret
  stw r11, sp[2]
  ldw ssr, sp[2]

  // stw r11, sp[1]
  // ldw spc, sp[1]
  // kret // No KRESTSP because sp is already what we want it to be, and we issued KENTSP with 0

.align 4
.L_outside_kernel:
  // Here we're outside the kernel and interrupts may happen

  bl proc_pcm

  // proc_pcm() has returned. Now we need to restore the original thread.
  // NOTE: interrupts can still fire in here, we're not in the kernel.

  // move SP back up 2 words
  ldaw sp, sp[4]

  // Restore the SPC, SSR, SED, ET
  ldw spc, sp[STK_SPC]
  ldw ssr, sp[STK_SSR]
  ldw sed, sp[STK_SED]
  ldw et, sp[STK_ET]

  // Restore , vector regs, DP, CP, LR
  ldw lr, sp[STK_LR]
  ldw dp, sp[STK_DP]
  ldw cp, sp[STK_CP]

  ldaw r11, sp[STK_VC]
  vldc r11[0]
  ldaw r11, sp[STK_VD]
  vldd r11[0]
  ldaw r11, sp[STK_VR]
  vldr r11[0]
  ldw r11, sp[STK_VCTRL]
  vsetc r11

  // Can I just load r0-r11 and krestsp/kret at this point??
  // the ISA doesn't say the instructions don't work if you're not in kernel mode..

  .L_finish_isr:

    ldd r11, r10, sp[STKD_R10R11]
    ldd r8, r9, sp[STKD_R8R9]
    ldd r2, r3, sp[STKD_R2R3]
    ldd r0, r1, sp[STKD_R0R1]
    
    ldd r6, r7, sp[STKD_R6R7]
    ldd r4, r5, sp[STKD_R4R5]
    krestsp 0
    kret



.L_func_end:
.cc_bottom FUNCTION_NAME.function

.global FUNCTION_NAME
// .type FUNCTION_NAME,@function

.size FUNCTION_NAME, .L_func_end - FUNCTION_NAME

#endif //defined(__XS3A__)


