// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

#define NSTACKWORDS   6

.text
.issue_mode single
.align 16


.globl deinterleave8
.globl deinterleave8.nstackwords
.globl deinterleave8.maxthreads
.globl deinterleave8.maxtimers
.globl deinterleave8.maxchanends
.linkset deinterleave8.nstackwords, NSTACKWORDS
.linkset deinterleave8.threads, 0
.linkset deinterleave8.maxtimers, 0
.linkset deinterleave8.chanends, 0

.type deinterleave8, @function

#define   x   r0
#define   a   r1
#define   b   r2
#define   c   r3
#define   d   r4
#define   e   r5
#define   f   r6
#define   g   r7
#define   h   r8


// r0 points to a double-word-aligned string of 256 bits.
// The bits have indices from 0 to 255, with words at higher addresses holding
// smaller bit indices, and LSbs of words containing smaller indices than MSbs.

// Then, all bits with index (k mod 8) correspond to microphone channel `k`.
// The point of this function is to take the bits that started in positions
// (k mod 8) and collect all 32 of them into word index k, for k in [0,1,..,7]

.cc_top deinterleave8.func,deinterleave8
deinterleave8:
  nop
  entsp NSTACKWORDS

  std r4, r5, sp[0]
  std r6, r7, sp[1]
  std r8, r9, sp[2]

  // Just load all 8 words into registers and everything will go real quick
  ldd a, b, x[3]
  ldd c, d, x[2]
  ldd e, f, x[1]
  ldd g, h, x[0]

  // The diagram below indicates which channels each register holds samples for,
  // expressed as an 8-bit mask. The idea is that we should never be unzipping
  // two registers that do not have the same mask.
/*
  Reg:   a   b   c   d   e   f   g   h
  Mask:  FF  FF  FF  FF  FF  FF  FF  FF
*/

  //First round of unzipping will separate channels {0,1,2,3} from {4,5,6,7} by
  // using a chunk size of 4 bits.

  unzip b, a, 2
  unzip d, c, 2
  unzip f, e, 2
  unzip h, g, 2

  //  a   b   c   d   e   f   g   h
  //  0F  F0  0F  F0  0F  F0  0F  F0

  // Now split in 2-bit chunks to separate into {0,1}, {2,3}, {4,5}, {6,7}

  unzip c, a, 1
  unzip d, b, 1
  unzip g, e, 1
  unzip h, f, 1

  //  a   b   c   d   e   f   g   h
  //  03  30  0C  C0  03  30  0C  C0

  // A final split with 1-bit chunks will finish separating everything

  unzip e, a, 0
  unzip f, b, 0
  unzip g, c, 0
  unzip h, d, 0

  //  a   b   c   d   e   f   g   h
  //  01  10  04  40  02  20  08  80

  // Now just put everything back where it belongs

  std e, a, x[0]
  std g, c, x[1]
  std f, b, x[2]
  std h, d, x[3]


  ldd r4, r5, sp[0]
  ldd r6, r7, sp[1]
  ldd r8, r9, sp[2]

  retsp NSTACKWORDS
.L_end:
.cc_bottom deinterleave8.func


.size deinterleave8, .L_end - deinterleave8

#endif // __XS3A__


#if defined(__VX4A__) || defined(__VX4B__)

#define FUNCTION_NAME deinterleave8
#define NSTACK_WORDS  8 
#define NSTACK_BYTES  (NSTACK_WORDS*4)

// Note: ldd and std are reversed in vx4

#define   x   a0
#define   a   a1
#define   b   a2

#define   c   s2
#define   d   s3
#define   e   s4
#define   f   s5
#define   g   s6
#define   h   s7

.p2align 1
.globl FUNCTION_NAME
.type FUNCTION_NAME,@function
FUNCTION_NAME:
  // save regs
  xm.entsp NSTACK_BYTES
  xm.stdsp  c, d, 0*8
  xm.stdsp  e, f, 1*8
  xm.stdsp  g, h, 2*8

  // deinterleave
  xm.ldd b, a, 24(x)
  xm.ldd d, c, 16(x)
  xm.ldd f, e, 8(x)
  xm.ldd h, g, 0(x)

  xm.unzip b, a, 2
  xm.unzip d, c, 2
  xm.unzip f, e, 2
  xm.unzip h, g, 2

  xm.unzip c, a, 1
  xm.unzip d, b, 1
  xm.unzip g, e, 1
  xm.unzip h, f, 1

  xm.unzip e, a, 0
  xm.unzip f, b, 0
  xm.unzip g, c, 0
  xm.unzip h, d, 0

  xm.std a, e, 0(a0)
  xm.std c, g, 8(a0)
  xm.std b, f, 16(a0)
  xm.std d, h, 24(a0)

  // restore regs
  xm.lddsp  c, d, 0*8
  xm.lddsp  e, f, 1*8
  xm.lddsp  g, h, 2*8
  xm.retsp  NSTACK_BYTES

.size FUNCTION_NAME, . -FUNCTION_NAME
.resource_const FUNCTION_NAME, "stack_frame_bytes", NSTACK_BYTES
.resource_list_empty FUNCTION_NAME, "callees"
.resource_list_empty FUNCTION_NAME, "tail_callees"
.resource_list_empty FUNCTION_NAME, "parallel_callees"

#endif // __VX4A__ || __VX4B__
