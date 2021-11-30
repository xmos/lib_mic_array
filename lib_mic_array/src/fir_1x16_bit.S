    // This function is the optimal FIR on a 1-bit signal with 16-bit coefficients.
    // r0: argument 1, signal (word aligned)
    // r1: argument 2, coefficients (arranged as 16 1-bit arrays, word aligned)
    // r2: argument 3, number of 256-bit chunks to operate on
    // r3: spare
    // r11: spare

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
    .align 8                                           // This alignment optimises lack of FNOPS

fir_1x16_bit:
    { dualentsp NSTACKWORDS        ; ldc r3, 32 }              // Allocate stack
    { vclrdr                       ; shl r11, r3, 3 }
    { vsetc r11                    ; ldaw r11, sp[0] }

.Linner_loop_xs3:
    { vldc r0[0]                   ; add r0, r0, r3 }    
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; add r1, r1, r3 }
    { vlmaccr1 r1[0]               ; sub r2, r2, 1  } // do sub before bt
    { bt r2, .Linner_loop_xs3      ; add r1, r1, r3 }
    
    vstr r11[0]
    vclrdr
    { vldc r11[0]                  ; ldap r11, macc_coeffs }
    { vlmaccr r11[0]               ; ldaw r2, sp[0] }
    { vstr r2[0]                   ; add r2, r2, 4 } 
    { vstd r2[0]                   ; nop }
    ldw r1, sp[1]
    { ldw r0, sp[0]                ; shl r1, r1, 16 }
    { retsp NSTACKWORDS            ; or r0, r0, r1 }

macc_coeffs:
    .short 0x7fff, 0x4000, 0x2000, 0x1000, 0x0800, 0x0400, 0x0200, 0x0100, 0x0080, 0x0040, 0x0020, 0x0010, 0x0008, 0x0004, 0x0002, 0x0001

    .cc_bottom fir_1x16_bit.func

