// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

#define NSTACKWORDS   0

.text
.issue_mode single
.align 16


.globl deinterleave2
.globl deinterleave2.nstackwords
.globl deinterleave2.maxthreads
.globl deinterleave2.maxtimers
.globl deinterleave2.maxchanends
.linkset deinterleave2.nstackwords, NSTACKWORDS
.linkset deinterleave2.threads, 0
.linkset deinterleave2.maxtimers, 0
.linkset deinterleave2.chanends, 0

.type deinterleave2, @function

#define   x   r0
#define   a   r1
#define   b   r2

.cc_top deinterleave2.func,deinterleave2
deinterleave2:
  nop
  entsp NSTACKWORDS
  ldd a, b, x[0]
  unzip b, a, 0
  std b, a, x[0]
  retsp NSTACKWORDS
.L_end:
.cc_bottom deinterleave2.func


.size deinterleave2, .L_end - deinterleave2

#endif // __XS3A__

#if defined(__VX4A__) || defined(__VX4B__)

#define FUNCTION_NAME deinterleave2
#define NSTACK_BYTES  16 // minimum

.p2align 1
.globl FUNCTION_NAME
.type FUNCTION_NAME,@function
FUNCTION_NAME:
    xm.entsp NSTACK_BYTES
    xm.ldd    a1, a2, 0(a0)    
    xm.unzip  a1, a2, 0         //Note: unzip swaps output positions
    xm.std    a2, a1, 0(a0)
    xm.retsp NSTACK_BYTES

.size FUNCTION_NAME, . -FUNCTION_NAME
.resource_const FUNCTION_NAME, "stack_frame_bytes", NSTACK_BYTES
.resource_list_empty FUNCTION_NAME, "callees"
.resource_list_empty FUNCTION_NAME, "tail_callees"
.resource_list_empty FUNCTION_NAME, "parallel_callees"

#endif // __VX4A__ || __VX4B__
