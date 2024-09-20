// Copyright 2020-2022 XMOS LIMITED.
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


