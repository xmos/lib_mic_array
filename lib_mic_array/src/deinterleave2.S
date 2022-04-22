// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

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