// Copyright 2021-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

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

