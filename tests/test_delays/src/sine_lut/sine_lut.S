
	.globl	sine_lut_sin
	.align	8
	.type	sine_lut_sin,@function
	.cc_top sine_lut_sin.function

#include "sine_lut_const.h"

#define theta r0
#define temp r1
#define p r11

.issue_mode single
//sine_lut_sin
sine_lut_sin:
/*
	entsp 0
	ldc temp, (SINE_LUT_INPUT_BITS-2)
	shr p, theta, temp
#if (SINE_LUT_INPUT_BITS - SINE_LUT_BITS-2) > 0
	shr theta, theta, (SINE_LUT_INPUT_BITS - SINE_LUT_BITS-2)
#endif
	zext p, 2
	shl p, p, 3
#if SINE_LUT_BITS != (SINE_LUT_INPUT_BITS-2)
	ldc temp, SINE_LUT_BITS
#endif
	.xtabranch l0, l1, l2, l3
	bru p

l0: zext theta, temp
	ldaw p, cp[sin_lut]
	ld16s r0, p[theta]
	zext r0, 16
	retsp 0
	nop
	nop

l1: neg theta, theta
	zext theta, temp
	bf theta, pos
	ldaw p, cp[sin_lut]
	ld16s r0, p[theta]
	zext r0, 16
	retsp 0

l2: zext theta, temp
	ldaw p, cp[sin_lut]
	ld16s r0, p[theta]
	zext r0, 16
	neg r0, r0
	retsp 0
	nop

l3: neg theta, theta
	zext theta, temp
	bf theta, neg
	ldaw p, cp[sin_lut]
	ld16s r0, p[theta]
	zext r0, 16
	neg theta, theta
	retsp 0

pos:ldc r0, SINE_LUT_OUTPUT_MAX_MAGNITUDE
	retsp 0
	nop
neg:ldc r0, SINE_LUT_OUTPUT_MAX_MAGNITUDE
	neg r0, r0
	*/
	retsp 0
	.cc_bottom sine_lut_sin.function
	.set	sine_lut_sin.nstackwords,0
	.globl	sine_lut_sin.nstackwords
	.set	sine_lut_sin.maxcores,1
	.globl	sine_lut_sin.maxcores
	.set	sine_lut_sin.maxtimers,0
	.globl	sine_lut_sin.maxtimers
	.set	sine_lut_sin.maxchanends,0
	.globl	sine_lut_sin.maxchanends
.Lend:
	.size	sine_lut_sin, .Lend-sine_lut_sin



