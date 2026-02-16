// Copyright 2023-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__XS3A__)

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

  // part2
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

#endif // __XS3A__

#if defined(__VX4A__) || defined(__VX4B__)

#define FUNCTION_NAME deinterleave16
#define NSTACK_WORDS  8 
#define NSTACK_BYTES  (NSTACK_WORDS*4)

#define   x   a0
#define   a   a1
#define   b   a2

#define   c   s2
#define   d   s3
#define   e   s4
#define   f   s5
#define   g   s6
#define   h   s7

// Note: ldd and std are reversed in vx4

.p2align 4
.globl FUNCTION_NAME
.type FUNCTION_NAME,@function
FUNCTION_NAME:
    // save regs
    xm.entsp NSTACK_BYTES
    xm.stdsp  s3,s2,0
    xm.stdsp  s5,s4,8
    xm.stdsp  s7,s6,16

    // Lower half
    xm.ldd b, a, (8*3)(x)
    xm.ldd d, c, (8*2)(x)
    xm.ldd f, e, (8*1)(x)
    xm.ldd h, g, (8*0)(x)

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

    xm.std a, e, (8*0)(x)
    xm.std c, g, (8*1)(x)
    xm.std b, f, (8*2)(x)
    xm.std d, h, (8*3)(x)

    // Upper half
    xm.ldd b, a, (8*7)(x)
    xm.ldd d, c, (8*6)(x)
    xm.ldd f, e, (8*5)(x)
    xm.ldd h, g, (8*4)(x)

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

    xm.std a, e, (8*4)(x)
    xm.std c, g, (8*5)(x)
    xm.std b, f, (8*6)(x)
    xm.std d, h, (8*7)(x)

    // part2
    xm.ldd b, a, (8*0)(x)
    xm.ldd d, c, (8*4)(x)
    xm.unzip b, d, 0
    xm.unzip a, c, 0
    xm.std b, a, (8*4)(x)
    xm.std d, c, (8*0)(x)

    xm.ldd b, a, (8*1)(x)
    xm.ldd d, c, (8*5)(x)
    xm.unzip b, d, 0
    xm.unzip a, c, 0
    xm.std b, a, (8*5)(x)
    xm.std d, c, (8*1)(x)

    xm.ldd b, a, (8*2)(x)
    xm.ldd d, c, (8*6)(x)
    xm.unzip b, d, 0
    xm.unzip a, c, 0
    xm.std b, a, (8*6)(x)
    xm.std d, c, (8*2)(x)

    xm.ldd b, a, (8*3)(x)
    xm.ldd d, c, (8*7)(x)
    xm.unzip b, d, 0
    xm.unzip a, c, 0
    xm.std b, a, (8*7)(x)
    xm.std d, c, (8*3)(x)

    // restore regs
    xm.lddsp  s3,s2,0
    xm.lddsp  s5,s4,8
    xm.lddsp  s7,s6,16
    xm.retsp  NSTACK_BYTES

.size FUNCTION_NAME, . -FUNCTION_NAME
.resource_const FUNCTION_NAME, "stack_frame_bytes", NSTACK_BYTES
.resource_list_empty FUNCTION_NAME, "callees"
.resource_list_empty FUNCTION_NAME, "tail_callees"
.resource_list_empty FUNCTION_NAME, "parallel_callees"

#endif
