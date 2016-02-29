// Copyright (c) 2016, XMOS Ltd, All rights reserved
	.section	.dp.data,"awd",@progbits
	.text

.xtacommand "analyse endpoints pdm_rx_4ch_loop_ep pdm_rx_4ch_loop_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints pdm_rx_8ch_loop_ep pdm_rx_8ch_loop_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__

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
#define temp_three           r11

#define CH0 0
#define CH1 1
#define CH2 4
#define CH3 5
#define CH4 2
#define CH5 3
#define CH6 6
#define CH7 7

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

.globl	pdm_rx_asm_debug
.align	8
.type	pdm_rx_asm_debug,@function
.cc_top pdm_rx_asm_debug.function
pdm_rx_asm_debug:
.cfi_startproc
.issue_mode dual
  bu pdm_rx_asm

	.cc_bottom pdm_rx_asm_debug.function
	.set	pdm_rx_asm_debug.nstackwords, 0 $M pdm_rx_asm.nstackwords
	.globl	pdm_rx_asm_debug.nstackwords
	.set	pdm_rx_asm_debug.maxcores, 1 $M pdm_rx_asm.maxcores
	.globl	pdm_rx_asm_debug.maxcores
	.set	pdm_rx_asm_debug.maxtimers,0
	.globl	pdm_rx_asm_debug.maxtimers
	.set	pdm_rx_asm_debug.maxchanends,0
	.globl	pdm_rx_asm_debug.maxchanends
.Lpdm_rx_asm_debug_tmp:
	.size	pdm_rx_asm_debug, .Lpdm_rx_asm_debug_tmp-pdm_rx_asm_debug
	.cfi_endproc

.cc_top pdm_rx_asm.function
.globl	pdm_rx_asm
.align	4
.type	pdm_rx_asm,@function
pdm_rx_asm://(
        //in buffered port:32 p_pdm_mics,
        //streaming chanend c,
        //streaming chanend ?d,

.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

	stw r0, sp[15]

#ifdef TEST_MODE
	ldc t, 0
#else
	ldc t, 0x5555
	shl t, t, 16; mov c, t
	add t, t, c
#endif
	std t, t, sp[0]
	std t, t, sp[1]
	std t, t, sp[2]
	std t, t, sp[3]
	std t, t, sp[4]
	std t, t, sp[5]

	ldaw t, cp[g_first_stage_fir_0]
	mov fir0, t
	ldaw t, cp[g_first_stage_fir_1]
	mov fir1, t
	ldaw t, cp[g_first_stage_fir_2]
	mov fir2, t

	ldaw p, sp[0]

	ldc c, CH0
	bt c_two, pdm_rx_8ch_loop

	ldc c, 0
	.align 8
pdm_rx_4ch_loop:

	ldw a, sp[15]
	in b, res[a]
	in a, res[a]
	unzip a, b, 2
	unzip a, b, 1
	unzip a, b, 0
	std a, b, p[0]

	FIR();
	OUTPUT(4, c_one)	//output c_one
	FIR();
	OUTPUT(2, c_one)	//output c_one
	FIR();
	{mov temp_one, a; ldc c, 6}
	FIR();
	{out res[c_one], temp_one}
	OUTPUT(0, c_one)	//output unused0 then this to c_one

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
	bl pdm_rx_4ch_loop
//2604ns per loop
	.align 8
pdm_rx_8ch_loop:
//about 6 inst spare without optimisation

	ldw a, sp[15]
	in b, res[a]
	in a, res[a]
	unzip a, b, 2
	unzip a, b, 1
	unzip a, b, 0
	std a, b, p[0]

	FIR();
	OUTPUT(CH1, c_one)	//output c_one
	FIR();
	OUTPUT(CH2, c_two)	//output c_two
	FIR();
	OUTPUT(CH3, c_one)	//output c_one
	FIR();
	OUTPUT(CH4, c_two)	//output c_two
	FIR();
	{mov temp_one, a; ldc c, CH5}
	FIR();
	{mov temp_two, a; ldc c, CH6}
	FIR();
	{mov temp_three, a; ldc c, CH7}
	FIR();
	{out res[c_one], temp_one}
	{out res[c_two], temp_two}
	{out res[c_one], temp_three}
	OUTPUT(CH0, c_two)

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
	bl pdm_rx_8ch_loop

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


#define EPT_MARCO(ID, PASS) \
.cc_top cc_a ## ID ## _ ## PASS,input_ ## ID ## _ ## PASS ;\
	.ascii	"";\
	.byte	0;\
	.long	0;\
	.long	input_ ## ID ## _ ## PASS;\
.cc_bottom cc_a ## ID ## _ ## PASS

	.section	.xtaendpoint,"",@progbits
.Lentries_start0:
	.long	.Lentries_end0-.Lentries_start0
	.long	1
	.ascii	""
    .byte	0

	.ascii	"pdm_rx_4ch_loop_ep"
	.byte	0
	.ascii	""
	.byte	0
	.long	0
	.long	.Laddr_end0 -.Laddr_start0
	.Laddr_start0:
	.cc_top cc_0 ,pdm_rx_4ch_loop
	.long	pdm_rx_4ch_loop
	.byte	0
	.cc_bottom cc_0
	.Laddr_end0 :

	.ascii	"pdm_rx_8ch_loop_ep"
	.byte	0
	.ascii	""
	.byte	0
	.long	0
	.long	.Laddr_end1 -.Laddr_start1
	.Laddr_start1:
	.cc_top cc_1 ,pdm_rx_8ch_loop
	.long	pdm_rx_8ch_loop
	.byte	0
	.cc_bottom cc_1
	.Laddr_end1 :
.Laddr_end9:

.Lentries_end0:

	.section	.xtaendpointtable,"",@progbits
.Lentries_start1:
	.long	.Lentries_end1-.Lentries_start1
	.long	0
	.ascii	""
	.byte	0

.cc_top cc_a0,pdm_rx_4ch_loop
	.ascii	""
	.byte	0
	.long	0
	.long	pdm_rx_4ch_loop
.cc_bottom cc_a0

.cc_top cc_a1,pdm_rx_8ch_loop
	.ascii	""
	.byte	0
	.long	0
	.long	pdm_rx_8ch_loop
.cc_bottom cc_a1


.Lentries_end1:

