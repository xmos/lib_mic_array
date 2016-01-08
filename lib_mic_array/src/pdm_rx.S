// Copyright (c) 2016, XMOS Ltd, All rights reserved
	.section	.dp.data,"awd",@progbits
	.text
#define temp_one 			 r0
#define c_one                r1
#define c_two                r2
#define a                 	 r3
#define b                 	 r4
#define fir0                 r5
#define fir1                 r6
#define fir2                 r7
#define temp_two             r8
#define c			     	 r9
#define p                 	 r10
#define t                 	 r11
#define unused3              r11

#define STACKWORDS 16

#define FIR_BLOCK(P) \
	{ld8u b, p[c]; add a, a, b};\
	{ldw b, P[b];add c, c, 8};

#define FIR() \
	{ld8u a, p[c]; ldc b, 0};\
	{ldw a, fir0[a]; add c, c, 8};\
	FIR_BLOCK(fir1)\
	FIR_BLOCK(fir2)\
	FIR_BLOCK(fir2)\
	FIR_BLOCK(fir1)\
	FIR_BLOCK(fir0)\
	add a, a, b

#define OUTPUT(I, C)\
	{out res[C], a; ldc c, I}


.cc_top pdm_rx_asm.function
.globl	pdm_rx_asm
.align	4
.type	pdm_rx_asm,@function
pdm_rx_asm://(
        //in buffered port:32 p_pdm_mics,
        //streaming chanend c,
        //streaming chanend d,

.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

	stw r0, sp[15]

	ldc t, 0
	std t, t, sp[0]
	std t, t, sp[1]
	std t, t, sp[2]
	std t, t, sp[3]
	std t, t, sp[4]
	std t, t, sp[5]

	ldaw t, cp[g_first_fir_0]
	mov fir0, t
	ldaw t, cp[g_first_fir_1]
	mov fir1, t
	ldaw t, cp[g_first_fir_2]
	mov fir2, t

	ldaw p, sp[0]

//2604ns per loop
	.align 8
pdm_rx_loop:
//about 6 inst spare without optimisation

	ldw a, sp[15]
	in b, res[a]
	in a, res[a]
	unzip a, b, 2
	unzip a, b, 1
	unzip a, b, 0
	std a, b, p[0]

	ldc c, 0
	FIR();
	OUTPUT(1, c_one)	//output c_one
	FIR();
	OUTPUT(2, c_two)	//output c_two
	FIR();
	OUTPUT(3, c_one)	//output c_one
	FIR();
	OUTPUT(4, c_two)	//output c_two
	FIR();
	{mov temp_one, a; ldc c, 5}
	FIR();
	{mov temp_two, a; ldc c, 6}
	FIR();
	{out res[c_one], temp_one}
	OUTPUT(7, c_one)	//output unused0 then this to c_one
	FIR();
	{out res[c_two], temp_two}	//TODO move the output of channel one to here to synchronise the threads
								// 		use unused3 as a temp for this
	OUTPUT(0, c_two)

	ldd a, b, p[4]
	std a, b, p[5]

	ldd a, b, p[3]
	std a, b, p[4]

	ldd a, b, p[2]
	{bitrev a, a; bitrev b, b}
	{byterev a, a; byterev b, b}
	std a, b, p[3]

	ldd a, b, p[1]
	std a, b, p[2]

	ldd a, b, p[0]
	std a, b, p[1]
	bl pdm_rx_loop

.pdm_rx_asm_tmp:
	.size	pdm_rx_asm, .pdm_rx_asm_tmp-pdm_rx_asm
	.align	4
	.cc_bottom pdm_rx_asm.function

	.set	pdm_rx_asm.nstackwords, STACKWORDS
	.globl	pdm_rx_asm.nstackwords
	.set	pdm_rx_asm.maxcores,1
	.globl	pdm_rx_asm.maxcores
	.set	pdm_rx_asm.maxtimers,0
	.globl	pdm_rx_asm.maxtimers
	.set	pdm_rx_asm.maxchanends,0
	.globl	pdm_rx_asm.maxchanends


	.cc_top pdm_rx_hires_delay.function
.globl	pdm_rx_hires_delay
.align	4
.type	pdm_rx_hires_delay,@function
pdm_rx_hires_delay:
.issue_mode dual
	DUALENTSP_lu6 STACKWORDS
	{ecallf r0;ecallt r0}
	retsp 0
.pdm_rx_hires_delay_tmp:
	.size	pdm_rx_hires_delay, .pdm_rx_hires_delay_tmp-pdm_rx_hires_delay
	.align	4
	.cc_bottom pdm_rx_hires_delay.function

	.set	pdm_rx_hires_delay.nstackwords, 0
	.globl	pdm_rx_hires_delay.nstackwords
	.set	pdm_rx_hires_delay.maxcores,1
	.globl	pdm_rx_hires_delay.maxcores
	.set	pdm_rx_hires_delay.maxtimers,0
	.globl	pdm_rx_hires_delay.maxtimers
	.set	pdm_rx_hires_delay.maxchanends,0
	.globl	pdm_rx_hires_delay.maxchanends


