// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#define NSTACKWORDS   2

.text
.issue_mode single
.align 16


.globl deinterleave4
.globl deinterleave4.nstackwords
.globl deinterleave4.maxthreads
.globl deinterleave4.maxtimers
.globl deinterleave4.maxchanends
.linkset deinterleave4.nstackwords, NSTACKWORDS
.linkset deinterleave4.threads, 0
.linkset deinterleave4.maxtimers, 0
.linkset deinterleave4.chanends, 0

.type deinterleave4, @function

#define   x   r0
#define   a   r1
#define   b   r2
#define   c   r3
#define   d   r4


// r0 points to a double-word-aligned string of 128 bits.
// The bits have indices from 0 to 127, with words at higher addresses holding
// smaller bit indices, and LSbs of words containing smaller indices than MSbs.

// Then, all bits with index (k mod 4) correspond to microphone channel `k`.
// The point of this function is to take the bits that started in positions
// (k mod 4) and collect all 32 of them into word index k, for k in [0,1,2,3]

.cc_top deinterleave4.func,deinterleave4
deinterleave4:
  nop
  entsp NSTACKWORDS

  std r4, r5, sp[0]

  // Just load all 4 words into registers and everything will go real quick
  ldd a, b, x[1]
  ldd c, d, x[0]

  // The diagram below indicates which channels each register holds samples for,
  // expressed as a 4-bit mask. The idea is that we should never be unzipping
  // two registers that do not have the same mask.
/*
  Reg:   a  b  c  d  
  Mask:  F  F  F  F
*/

  //First round of unzipping will separate channels {0,1} from {2,3} by
  // using a chunk size of 2 bits.

  unzip b, a, 1
  unzip d, c, 1

  //  a   b   c   d
  //  3   C   3   C

  // Now split the rest of the way

  unzip c, a, 0
  unzip d, b, 0

  // Now just put everything back where it belongs

  std c, a, x[0]
  std d, b, x[1]

  ldd r4, r5, sp[0]

  retsp NSTACKWORDS
.L_end:
.cc_bottom deinterleave4.func


.size deinterleave4, .L_end - deinterleave4