// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#define NSTACKWORDS   6

.text
.issue_mode single
.align 16


.globl deinterleave16
.globl deinterleave16.nstackwords
.globl deinterleave16.maxthreads
.globl deinterleave16.maxtimers
.globl deinterleave16.maxchanends
.linkset deinterleave16.nstackwords, NSTACKWORDS
.linkset deinterleave16.threads, 0
.linkset deinterleave16.maxtimers, 0
.linkset deinterleave16.chanends, 0

.type deinterleave16, @function

#define   x   r0
#define   a   r1
#define   b   r2
#define   c   r3
#define   d   r4
#define   e   r5
#define   f   r6
#define   g   r7
#define   h   r8


// r0 points to a double-word-aligned string of 512 = 16 * 32 bits.
// The bits have indices from 0 to 511, with words at higher addresses holding
// smaller bit indices, and LSbs of words containing smaller indices than MSbs.

// Then, all bits with index (k mod 16) correspond to microphone channel `k`.
// The point of this function is to take the bits that started in positions
// (k mod 16) and collect all 32 of them into word index k, for k in [0,1,..,15]

.cc_top deinterleave16.func,deinterleave16
deinterleave16:
  nop
  entsp NSTACKWORDS

  std r4, r5, sp[0]
  std r6, r7, sp[1]
  std r8, r9, sp[2]
  
  // Lower half
  ldd a, b, x[3]
  ldd c, d, x[2]
  ldd e, f, x[1]
  ldd g, h, x[0]

  unzip b, a, 2
  unzip d, c, 2
  unzip f, e, 2
  unzip h, g, 2

  unzip c, a, 1
  unzip d, b, 1
  unzip g, e, 1
  unzip h, f, 1

  unzip e, a, 0
  unzip f, b, 0
  unzip g, c, 0
  unzip h, d, 0

  std e, a, x[0]
  std g, c, x[1]
  std f, b, x[2]
  std h, d, x[3]
  
  // Upper half
  ldd a, b, x[7]
  ldd c, d, x[6]
  ldd e, f, x[5]
  ldd g, h, x[4]

  unzip b, a, 2
  unzip d, c, 2
  unzip f, e, 2
  unzip h, g, 2

  unzip c, a, 1
  unzip d, b, 1
  unzip g, e, 1
  unzip h, f, 1

  unzip e, a, 0
  unzip f, b, 0
  unzip g, c, 0
  unzip h, d, 0

  std e, a, x[4]
  std g, c, x[5]
  std f, b, x[6]
  std h, d, x[7]


  ldd a, b, x[0]
  ldd c, d, x[4]
  unzip b, d, 0
  unzip a, c, 0
  std a, b, x[4]
  std c, d, x[0]

  ldd a, b, x[1]
  ldd c, d, x[5]
  unzip b, d, 0
  unzip a, c, 0
  std a, b, x[5]
  std c, d, x[1]

  ldd a, b, x[2]
  ldd c, d, x[6]
  unzip b, d, 0
  unzip a, c, 0
  std a, b, x[6]
  std c, d, x[2]

  ldd a, b, x[3]
  ldd c, d, x[7]
  unzip b, d, 0
  unzip a, c, 0
  std a, b, x[7]
  std c, d, x[3]

  ldd r4, r5, sp[0]
  ldd r6, r7, sp[1]
  ldd r8, r9, sp[2]

  retsp NSTACKWORDS
.L_end:
.cc_bottom deinterleave16.func


.size deinterleave16, .L_end - deinterleave16