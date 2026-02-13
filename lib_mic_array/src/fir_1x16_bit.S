// Copyright 2021-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifdef __XS3A__ // Only available for xcore.ai

/**
 * This function is the optimal FIR on a 1-bit signal with 16-bit coefficients.
 *
 * NOTE: This version is optimized for the mic array and takes only a single block of coefficients
 *
 * r0: argument 1, signal (word aligned)
 * r1: argument 2, coefficients (arranged as 16 1-bit arrays, word aligned)
 * r2: spare
 * r3: spare
 * r11: spare
*/

#define NSTACKWORDS   10
    .globl fir_1x16_bit
    .globl fir_1x16_bit.nstackwords
    .globl fir_1x16_bit.maxthreads
    .globl fir_1x16_bit.maxtimers
    .globl fir_1x16_bit.maxchanends
    .linkset fir_1x16_bit.nstackwords, NSTACKWORDS
    .linkset fir_1x16_bit.threads, 0
    .linkset fir_1x16_bit.maxtimers, 0
    .linkset fir_1x16_bit.chanends, 0

    .cc_top fir_1x16_bit.func, fir_1x16_bit
    .type fir_1x16_bit, @function
    
    .text
    .issue_mode dual
    .align 16

fir_1x16_bit:
    { ldc r3, 32                  ; dualentsp NSTACKWORDS       }
    { shl r11, r3, 3              ; vclrdr                      }
    {                             ; vsetc r11                   }
    {                             ; vldc r0[0]                  }    
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { add r1, r1, r3              ; vlmaccr1 r1[0]              }
    { ldaw r11, sp[0]             ; vlmaccr1 r1[0]              }
    {                             ; vstr r11[0]                 }
    {                             ; vclrdr                      }
    { ldap r11, macc_coeffs       ; vldc r11[0]                 }
    { ldaw r2, sp[0]              ; vlmaccr r11[0]              }
    { add r2, r2, 4               ; vstr r2[0]                  } 
    {                             ; vstd r2[0]                  }
      ldd r1, r0, sp[0]
      zip r1, r0, 4
    { retsp NSTACKWORDS           ; shl r0, r0, 8               }

// The order of these coefficients tells us that whatever gets VLMACCR1'ed last is going to be multiplied by
//  the largest coefficient. Thus, if the bipolar coefficient matrix B[,] has shape 16x32, then B[0,:] must
//  correspond to the LEAST significant bits of each coefficient
macc_coeffs:
    .short 0x7fff, 0x4000, 0x2000, 0x1000, 0x0800, 0x0400, 0x0200, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001
    .cc_bottom fir_1x16_bit.func

#endif // __XS3A__


#if defined(__VX4A__) || defined(__VX4B__)

/**
 * This function is the optimal FIR on a 1-bit signal with 16-bit coefficients.
 *
 * NOTE: This version is optimized for the mic array and takes only a single block of coefficients
 *
 * r0: argument 1, signal (word aligned)
 * r1: argument 2, coefficients (arranged as 16 1-bit arrays, word aligned)
 * r2: spare
 * r3: spare
 * r11: spare
*/

#define FUNCTION_NAME fir_1x16_bit
#define NSTACK_WORDS  16 
#define NSTACK_BYTES  (NSTACK_WORDS*4)

.p2align 4
.globl FUNCTION_NAME
.type FUNCTION_NAME,@function
FUNCTION_NAME:
    { li a3, 32                   ; xm.entsp NSTACK_BYTES}
    { slli t3, a3, 3              ; xm.vclrdr  }
    { xm.nop                         ; xm.vsetc t3}
    { xm.nop                         ; xm.vldc a0}    
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { add a1, a1, a3              ; xm.vlmaccrb a1}
    { addi t3,sp, 0               ; xm.vlmaccrb a1}
    { xm.nop                         ; xm.vstr t3}
    { xm.nop                         ; xm.vclrdr}
    { xm.ldap t3, macc_coeffs     ; xm.vldc t3}
    { addi a2,sp, 0               ; xm.vlmaccr0 t3}
    { addi a2, a2, 4              ; xm.vstr a2} 
    { xm.nop                         ; xm.vstd a2}
    xm.lddsp a0,a1,0
    xm.zip a1,a0,4
    { xm.retsp NSTACK_BYTES      ; slli a0, a0, 8}

// The order of these coefficients tells us that whatever gets VLMACCR1'ed last is going to be multiplied by
//  the largest coefficient. Thus, if the bipolar coefficient matrix B[,] has shape 16x32, then B[0,:] must
//  correspond to the LEAST significant bits of each coefficient
macc_coeffs:
    .short 0x7fff, 0x4000, 0x2000, 0x1000, 0x0800, 0x0400, 0x0200, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001

#endif // __VX4A__ || __VX4B__
