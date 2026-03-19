// Copyright 2020-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

#include "xs1.h"

/*  

Function for counting the MIPS available for a core.

void count_mips();

*/


.section .dp.data, "awd", @progbits

.align 8
tick_count: .word 0, 0
inst_count: .word 0, 0

.global tick_count
.global inst_count

#define NSTACKWORDS     (0)

#define FUNCTION_NAME   count_mips

#define p_tick_count  r0
#define p_inst_count  r1
#define last_time     r2
#define tick_lo       r3
#define tick_hi       r4
#define inst_lo       r5
#define inst_hi       r6
#define one           r7
#define tmp           r8

.text
.issue_mode dual
.align 16

.cc_top FUNCTION_NAME.function,FUNCTION_NAME
FUNCTION_NAME:
    dualentsp NSTACKWORDS
  // Never returns, so no need to save any registers

    // Get pointers for the two counters
    ldap r11, tick_count
    mov p_tick_count, r11
    ldap r11, inst_count
    mov p_inst_count, r11

  // Initialize counters to 0
  { ldc tick_lo, 0                        ; ldc tick_hi, 0                        }
  { ldc inst_lo, 0                        ; ldc inst_hi, 0                        }

  // maccu coefficient is one because we just want to add
  { ldc one, 1                            ;                                       }     

  // initialize the last timestamp, and jump to the loop
  { gettime last_time                     ; bu .L_loop_top                        }

# define LOOP_INST  8

  .align 16
  .L_loop_top:
    // this loop should be 8 thread cycles long (no FNOPS needed)
      ldc tmp, LOOP_INST
    // increment instruction counter
      maccu inst_lo, inst_hi, one, tmp

    // Get current time
    { gettime tmp                           ;                                       }
    // Subtract previous time (this approach should be immune to ref clock rollovers, 
    // rather than just subtracting a start time)
    { sub tmp, tmp, last_time               ; mov last_time, tmp                    }
    // increment tick counter
      maccu tick_lo, tick_hi, one, tmp

    // Store both counters in memory, and repeat
      std tick_lo, tick_hi, p_tick_count[0]
      std inst_lo, inst_hi, p_inst_count[0]

    {                                       ; bu .L_loop_top                        }
  .L_loop_bot:
    


.L_func_end:
.cc_bottom FUNCTION_NAME.function


.global FUNCTION_NAME
.type FUNCTION_NAME,@function

.set FUNCTION_NAME.nstackwords,NSTACKWORDS;     .global FUNCTION_NAME.nstackwords
.set FUNCTION_NAME.maxcores,1;                  .global FUNCTION_NAME.maxcores
.set FUNCTION_NAME.maxtimers,0;                 .global FUNCTION_NAME.maxtimers
.set FUNCTION_NAME.maxchanends,0;               .global FUNCTION_NAME.maxchanends
.size FUNCTION_NAME, .L_func_end - FUNCTION_NAME

#endif //defined(__XS3A__)

#if defined(__VX4A__) || defined(__VX4B__)

#define FUNCTION_NAME count_mips
#define NSTACK_BYTES  16
#define LOOP_INST     8

.section .data
.p2align 3
.global tick_count
.global inst_count
tick_count: .word 0, 0
inst_count: .word 0, 0

.section .text
.p2align 3
.globl FUNCTION_NAME
.type FUNCTION_NAME,@function

FUNCTION_NAME:
    xm.entsp NSTACK_BYTES
    // Never returns, so no need to save any registers
    // Get pointers for the two counters
    lui  t3, %hi(tick_count)
    addi t3, t3, %lo(tick_count)
    mv   a0, t3
    lui  t3, %hi(inst_count)
    addi t3, t3, %lo(inst_count)
    mv   a1, t3
    // Initialize counters to 0
    { li a3, 0  ; li s2, 0 }
    { li s3, 0  ; li s4, 0 }
    // maccu coefficient is s5 because we just want to add
    { li s5, 1  ; nop }
    // initialize the last timestamp, and jump to the loop
    { xm.gettime a2  ; xm.bu .L_loop_top }
.p2align 4
.L_loop_top:
    // this loop should be 8 thread cycles long (no FNOPS needed)
    xm.ldcu s6, LOOP_INST
    // increment instruction counter
    xm.maccu s3, s4, s5, s6
    // Get current time
    xm.gettime s6
    // Subtract previous time 
    { sub s6, s6, a2  ; mv a2, s6 }
    // increment tick counter
    xm.maccu a3, s2, s5, s6
    // Store both counters in memory, and repeat
    xm.stdi s2, a3, 0(a0)
    xm.stdi s4, s3, 0(a1)
    xm.bu .L_loop_top
.L_loop_bot:
.L_func_end:
    xm.retsp NSTACK_BYTES

.size FUNCTION_NAME, . -FUNCTION_NAME
.resource_const FUNCTION_NAME, "stack_frame_bytes", NSTACK_BYTES
.resource_list_empty FUNCTION_NAME, "callees"
.resource_list_empty FUNCTION_NAME, "tail_callees"
.resource_list_empty FUNCTION_NAME, "parallel_callees"

#endif // __VX4A__ || __VX4B__
