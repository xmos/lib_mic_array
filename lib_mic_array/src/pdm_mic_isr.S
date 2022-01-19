// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

#include "xs1.h"

/*  

  File contains the ISR logic for capturing PDM samples coming in.
  

  For the layout (and descriptions) of the stack used in this ISR, see the struct 
  `ma_pdm_rx_context_t` in pdm_rx.h.

  NOTE: these likely need to be rearranged to optimize access, but I'll deal with that later.

*/

// These STK_ macros basically represent the ma_pdm_rx_static_t type from pdm_rx.h
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

#define STK_STATE       45

#define STK_PHASE1      (STK_STATE+0)
#define STK_PDM_RAW     (STK_STATE+1)
#define STK_PHASE2      (STK_STATE+9)

#define STK_CONFIG      (STK_STATE+10)

#define STK_MIC_COUNT   (STK_CONFIG+0)
#define STK_PORT        (STK_CONFIG+1)
#define STK_FIR_COEF    (STK_CONFIG+2)
#define STK_COEF_BLKS   (STK_CONFIG+3)
#define STK_PDM_BUFF    (STK_CONFIG+4)
#define STK_STG2_DEC    (STK_CONFIG+5)
#define STK_PCM_VECT    (STK_CONFIG+6)

.text
.issue_mode dual
.align 16         // 16-byte alignment guarantees that FNOPs always happen in the same spots

#define A   r4
#define B   r5
#define C   r6
#define D   r7
#define E   r8
#define F   r9

.cc_top pdm_rx_isr.function,pdm_rx_isr

pdm_rx_isr:

    kentsp 0          
    dualentsp 0        
    std r4, r5, sp[STKD_R4R5]
    std r6, r7, sp[STKD_R6R7]
  { ldaw D, sp[STK_PDM_RAW]               ; ldw A, sp[STK_PORT]                   }
  { in A, res[A]                          ; ldw C, sp[STK_PHASE1]                 }
    stw A, D[C]
  { sub C, C, 1                           ; bf C, .L_unzip_stuff                  }
  {                                       ; stw C, sp[STK_PHASE1]                 }
    ldd r6, r7, sp[STKD_R6R7]
    ldd r4, r5, sp[STKD_R4R5]
    krestsp 0
    kret

.L_unzip_stuff:
    std r0, r1, sp[STKD_R0R1]
    std r2, r3, sp[STKD_R2R3]
    std r8, r9, sp[STKD_R8R9]
    std r11, r10, sp[STKD_R10R11]

  // Reset phase1 number
  { ldc D, 31                             ; ldw A, sp[STK_MIC_COUNT]              }
  { sub B, A, 1                           ; clz A, A                              }
  { sub A, D, A                           ; stw B, sp[STK_PHASE1]                 }

  // Now behavior depends on the number of active mics. Note that the raw PDM sample
  // words are stored in reverse order, so that sp[STK_PDM_RAW+0] is the most recent

  // A currently contains log2(sp[STK_MIC_COUNT])

  {                                       ; ldw C, sp[STK_COEF_BLKS]              }
  { shl C, C, 5                           ; ldw D, sp[STK_PDM_BUFF]               }
  {                                       ; bru A                                 }
  .jmptable32 .L_unzip_pdm_1mic, .L_unzip_pdm_2mic, .L_unzip_pdm_4mic, .L_unzip_pdm_8mic

  .L_unzip_pdm_1mic:
    // For 1 mic, there's no unzipping to do, just move it to the correct location
    {                                       ; ldw A, sp[STK_PDM_RAW+0]            }
    {                                       ; stw A, D[0]                         }
      bu .L_decimate
  .L_unzip_pdm_2mic:
    {                                       ; ldw A, sp[STK_PDM_RAW+1]            }
    {                                       ; ldw B, sp[STK_PDM_RAW+0]            }
      unzip B, A, 0 // So, I *think* I've done unzip correctly here, but I'm not certain
    { add D, D, C                           ; stw A, D[0]                         }
    {                                       ; stw B, D[0]                         }
      bu .L_decimate

  .L_unzip_pdm_4mic:
      ecallt C  // TODO: NOT YET IMPLEMENTED

  .L_unzip_pdm_8mic:
      ecallt C  // TODO: NOT YET IMPLEMENTED

  // Now the PDM samples are unzipped and in the PDM buffer. Time to decimate
  
  .L_decimate:

#define ENABLE_COUNTERS   1 // Adds about 0.288 MIPS
#if ENABLE_COUNTERS
  // TODO: This is just for debugging for the moment
  { ldc B, 32                             ;                                       }
    ldw A, dp[pdm_sample_count]
  { add A, A, B                           ;                                       }
    stw A, dp[pdm_sample_count]
#endif // ENABLE_COUNTERS

  // C <-- mic count
  // D <-- pointer to PDM sample buffers
  // B <-- pointer to PCM sample buffer
  {                                       ; ldw C, sp[STK_MIC_COUNT]              }
  {                                       ; ldw D, sp[STK_PDM_BUFF]               }
  {                                       ; ldw B, sp[STK_PCM_VECT]               }
  
  // A <-- stage1 block count
  {                                       ; ldw A, sp[STK_COEF_BLKS]              }

  // Save the link register because it will be clobbered when we call the filter function,
  // potentially screwing up the interrupted thread.
  {                                       ; stw lr, sp[STK_LR]                    }

  // F <-- stage2 decimation factor
  // The PCM sample vector has shape int32[MIC_COUNT][STG2_DEC_FACTOR]
  // A <-- [stage1 block count] * [bytes per 256 PDM samples]
  { shl A, A, 5                           ; ldw F, sp[STK_STG2_DEC]               }

  // E <-- Current phase2 value
  // F <-- [stage2 dec factor] * sizeof(int32_t)
  { shl F, F, 2                           ; ldw E, sp[STK_PHASE2]                 }
    ldaw B, B[E]

  // Loop: Apply PDM to 32-bit PCM decimation. Loops once per microphone.
  .L_pdm_to_pcm_loop_top:
    // Make function call, placing arguments in r0, r1, r2
    // fir_1x16_bit(PDM_buffer_pointer, stage1_coef_pointer, stage1_coef_blocks)
    { mov r0, D                             ; ldw r1, sp[STK_FIR_COEF]              }
    { sub C, C, 1                           ; ldw r2, sp[STK_COEF_BLKS]             }

    // Call the stage1 decimation filter 
      bl fir_1x16_bit
    //r0 now has the 32-bit result.

    // D <-- [move D to point at next microphone's PDM buffer]
    // Store the PCM sample in the PCM vector for this microphone
    { add D, D, A                           ; stw r0, B[0]                          }

    // B <-- [move B to point at next microphones PCM vector]
    { add B, B, F                           ; bt C, .L_pdm_to_pcm_loop_top          }
  .L_pdm_to_pcm_loop_bot:

  // Now we should shift each channel's PDM buffer up one word
  // This can be easily accomplished using the VPU with a VLMACCR 
  // in 32-bit mode. This op is circular, but we don't care what
  // ends up in the first word.

  { ldc r11, 0                            ; ldw C, sp[STK_MIC_COUNT]              }
  { ldc D, 32                             ; ldw E, sp[STK_PDM_BUFF]               }
  {                                       ; vsetc r11                             }

  // This version of this loop assumes only 1 block of coefficients
  .L_pdm_shift_loop_top:
    { sub C, C, 1                           ; vldd E[0]                             }
    {                                       ; vlmaccr E[0]                          }
    { add E, E, D                           ; vstd E[0]                             }
    {                                       ; bt C, .L_pdm_shift_loop_top           }
  .L_pdm_shift_loop_bot:

  // { ldc r11, 0                            ; ldw C, sp[STK_MIC_COUNT]              }
  // { ldc D, 32                             ; ldw A, sp[STK_COEF_BLKS]              }
  // { shl B, A, 5                           ; ldw E, sp[STK_PDM_BUFF]               }
  // { add E, E, B                           ; vsetc r11                             }
  // { sub E, E, D                           ;                                       }

  // .L_pdm_shift_loop_top:
  //   { sub C, C, 1                           ; vldd E[0]                             }
  //   { sub r11, E, D                         ; vlmaccr E[0]                          }
  //   { sub r10, A, 1                         ; vstd E[0]                             }
  //   { add E, E, B                           ; bf r10, .L_pdm_shift_inner_bot        }
  //   .L_pdm_shift_inner_top:
  //     { add F, r11, 4                         ; vldd r11[0]                           }
  //     { sub r11, r11, D                       ; vstd F[0]                             }
  //     { sub r10, r10, 1                       ; bt r10, .L_pdm_shift_inner_top        }
  //   .L_pdm_shift_inner_bot:
  //   {                                       ; bt C, .L_pdm_shift_loop_top           }
  // .L_pdm_shift_loop_bot:



  // Increment phase2, and if [it's] == [the decimation factor], we'll need to 
  // perform a context switch and call proc_pcm().
  // If E<F, we can just reload the stored registers.
  {                                       ; ldw E, sp[STK_PHASE2]                 }
  { add E, E, 1                           ; ldw F, sp[STK_STG2_DEC]               }

  // note: This may seem like a weird way to do this, but it's because it avoids branching
  { eq r0, E, F                           ;                                       }
    mul F, F, r0
  { sub E, E, F                           ;                                       }

  {                                       ; stw E, sp[STK_PHASE2]                 }
  {                                       ; bf r0, .L_finish_isr                  }

  
  // Okay, now we have to force a context switch for the thread that was interrupted.
  //  - save the rest of the interrupted thread's state into the workspace,
  //  - set this thread's registers (specifically, the SP and PC we'll be returning
  //      to when this ISR completes) to call the PCM decimator function
  //  - when that completes, restore the original interrupted thread's state

  // Save the SPC, SSR, SED, ET
  {                                       ; stw spc, sp[STK_SPC]                  }
  {                                       ; stw ssr, sp[STK_SSR]                  }
  {                                       ; stw sed, sp[STK_SED]                  }
  {                                       ; stw et, sp[STK_ET]                    }

  // Save DP, CP, LR, vector regs
  {                                       ; stw dp, sp[STK_DP]                    }
  {                                       ; stw cp, sp[STK_CP]                    }

  // Set DP and CP  // Maybe not necessary? I was hoping it would prevent this crash I keep seeing..
    ldap r11, _dp
    set dp, r11
    ldap r11, _cp
    set cp, r11


  {                                       ; vgetc r11                             }
  { ldaw r11, sp[STK_VR]                  ; stw r11, sp[STK_VCTRL]                }
  { ldaw r11, sp[STK_VD]                  ; vstr r11[0]                           }
  { ldaw r11, sp[STK_VC]                  ; vstd r11[0]                           }
  { ldc r11, 1                            ; vstc r11[0]                           }

  // Now we want to call proc_pcm(). 
  { shl r11, r11, 8                       ; ldw r0, sp[STK_PCM_VECT]              }
  { add r11, r11, 2                       ; extsp 4                               }
  // NOTE: Be careful with the STK_* defines in here

  // r11 = 0x102 -- dual-issue and enable interrupts
  {                                       ; stw r11, sp[2]                        }
  {                                       ; ldw ssr, sp[2]                        }
    ldap r11, .L_outside_kernel
  {                                       ; stw r11, sp[1]                        }
  {                                       ; ldw spc, sp[1]                        }
  // No KRESTSP because sp is already what we want it to be, and we issued KENTSP with 0
    kret 

.L_outside_kernel:
  // Here we're outside the kernel and interrupts may happen
  bl proc_pcm

  // proc_pcm() has returned. Now we need to restore the original thread.
  // NOTE: interrupts can still fire in here, we're not in the kernel.

  {                                       ; ldw r11, sp[STK_VCTRL+4]              }
  { ldaw sp, sp[4]                        ; vsetc r11                             }

  // Restore the SPC, SSR, SED, ET
  {                                       ; ldw spc, sp[STK_SPC]                  }
  {                                       ; ldw ssr, sp[STK_SSR]                  }
  {                                       ; ldw sed, sp[STK_SED]                  }
  {                                       ; ldw et, sp[STK_ET]                    }

  // Restore , vector regs, DP, CP, LR
  {                                       ; ldw lr, sp[STK_LR]                    }
  {                                       ; ldw dp, sp[STK_DP]                    }
  { ldaw r11, sp[STK_VC]                  ; ldw cp, sp[STK_CP]                    }

  { ldaw r11, sp[STK_VD]                  ; vldc r11[0]                           }
  { ldaw r11, sp[STK_VR]                  ; vldd r11[0]                           }
  {                                       ; vldr r11[0]                           }

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
.cc_bottom pdm_rx_isr.function

.global pdm_rx_isr
.global pdm_rx_isr_1mic
// .type pdm_rx_isr,@function

// .size pdm_rx_isr, .L_func_end - pdm_rx_isr

#endif //defined(__XS3A__)


