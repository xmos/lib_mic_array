	.section	.dp.data,"awd",@progbits
	.text
	.cc_top decimate_to_pcm_4ch_48KHz.function
	.globl	decimate_to_pcm_4ch_48KHz
	.align	4
	.type	decimate_to_pcm_4ch_48KHz,@function

#include "defines.h"

#define c_input  			 r0
#define c_output   			 r1
#define p_int   			 r2
#define p_comb   			 r3

#define s			 		 r4
#define t 			 	     r5
#define a 			         r6
#define b			         r7
#define mask			     r8
#define counter			     r9
#define comb_output			 r10

//not using r11! ops

#define S_CHAN_INPUT 7
#define S_COMB_POINTER 8

#define COMB(p, N) \
		ldd a, b, p[N];\
		{sub t, t, a ; mov a, t};\
		{sub t, t, b ; mov b, t};\
		std a, b, p[N];

#define INT(p, N, M) \
	ldd a, b, p[N];\
	{add a, a, s; add b, b, t};\
	std a, b, p[N];\
	ldd s, t, p[M];\
	{add s, s, a; add t, t, b};\
	std s, t, p[M];

#define SECOND_STAGE_N 6
#define FILTER_PATHS   4
#define STACK 32

#define S_COMB_1_0 0
#define S_COMB_1_1 1
#define S_COMB_1_2 2

#define S_COMB_2_0 3
#define S_COMB_2_1 4
#define S_COMB_2_2 5
#define S_COMB_2_4 6

//This muse be double word aligned
#define S_FILTERED_0 8
#define S_FILTERED_1 9
#define S_FILTERED_2 10
#define S_FILTERED_3 11

#define S_FILTERED_0_1 4
#define S_FILTERED_2_3 5

#define S_PREV_X_0 12
#define S_PREV_Y_0 13
#define S_PREV_X_1 14
#define S_PREV_Y_1 15
#define S_PREV_X_2 16
#define S_PREV_Y_2 17
#define S_PREV_X_3 18
#define S_PREV_Y_3 19

#define S_AUDIO_POINTER 20
#define S_AUDIO_POINTER_INDEX 21

#define NSTACKWORDS (STACK + SECOND_STAGE_N*FILTER_PATHS+SECOND_STAGE_N*FILTER_PATHS)

decimate_to_pcm_4ch_48KHz:
.align 8
.issue_mode dual

	//extend the stack
	DUALENTSP_lu6 NSTACKWORDS

	ldaw p_int,  sp[STACK]
	ldaw p_comb, sp[STACK+(SECOND_STAGE_N*FILTER_PATHS)]

	ldc t, 0

	stw t,  sp[S_PREV_X_0]
	stw t,  sp[S_PREV_Y_0]
	stw t,  sp[S_PREV_X_1]
	stw t,  sp[S_PREV_Y_1]
	stw t,  sp[S_PREV_X_2]
	stw t,  sp[S_PREV_Y_2]
	stw t,  sp[S_PREV_X_3]
	stw t,  sp[S_PREV_Y_3]

	std t, t, sp[0]
	std t, t, sp[1]
	std t, t, sp[2]
	std t, t, sp[3]

	ldc counter, 0
	ldc a, 12
	mem_init_loop:
		std t, t, p_int[counter]
		std t, t, p_comb[counter]
		add counter, counter, 1
		sub b, counter, a
		bt b, mem_init_loop

	ldw mask, cp[cic_mask]//0x7f7f7f7f
	{ldc counter, 0;not mask, mask}

	ldc t, 0
	stw t, sp[S_AUDIO_POINTER_INDEX]

	//grab the first pointer
    in t, res[c_output]
	stw t, sp[S_AUDIO_POINTER]

ds_loop:
	//comb the output from the mic listener
	{in a, res[c_input]    ; nop}
	{add s, a, mask        ; ldw t, sp[S_COMB_1_0]}
	{sub s, s, t           ; stw a, sp[S_COMB_1_0]}
	{andnot s, mask        ; nop}
	{add a, s, mask        ; ldw t, sp[S_COMB_1_1]}
	{sub comb_output, a, t ; stw s, sp[S_COMB_1_1]}
	{nop                   ; andnot comb_output, mask}

	//comb_output contains 4 bytes of comb mic data

	// Integrate - mic 0 and 1
	{mov s, comb_output    ; shr t, comb_output, 8}
	{zext s, 8; zext t,  8}
	INT(p_int, 0, 1)
	INT(p_int, 2, 3)
	INT(p_int, 4, 5)

	// Integrate - mic 2 and 3
	{shr s, comb_output, 16; shr t, comb_output, 24}
	{zext s,  8; zext t,  8}
	INT(p_int, 6, 7)
	INT(p_int, 8, 9)
	INT(p_int, 10, 11)

	//~50 instructions used

	//TODO improve to allow dividers > 8
	zext counter, 3
	{bru counter; add counter, counter, 1}

	bu comb			//0
	bu ds_loop		//1
	bu ds_loop		//2
	bu ds_loop		//3
	bu ds_loop		//4
	bu ds_loop		//5
	bu ds_loop		//6
	bu bitrev		//7

comb:
	//load the integral
	ldw t, sp[STACK + 10]
	COMB(p_comb, 0)
	COMB(p_comb, 1)
	COMB(p_comb, 2)
	stw t, sp[S_FILTERED_0]

	ldw t, sp[STACK + 11]
	COMB(p_comb, 3)
	COMB(p_comb, 4)
	COMB(p_comb, 5)
	stw t, sp[S_FILTERED_1]

	ldw t, sp[STACK + 22]
	COMB(p_comb, 6)
	COMB(p_comb, 7)
	COMB(p_comb, 8)
	stw t, sp[S_FILTERED_2]

	ldw t, sp[STACK + 23]
	COMB(p_comb, 9)
	COMB(p_comb, 10)
	COMB(p_comb, 11)
	stw t, sp[S_FILTERED_3]
	bu ds_loop

bitrev:

    ldw a, sp[S_AUDIO_POINTER_INDEX]
	ldw b, sp[S_AUDIO_POINTER]
	{ldw t, sp[S_FILTERED_0];}
	{ldw s, sp[S_FILTERED_1];}
	std s, t, b[a]
	{ldc a, (1<<FRAME_SIZE_LOG2)*1}
	{ldw b, sp[S_AUDIO_POINTER]}
	{ldw t, sp[S_AUDIO_POINTER_INDEX];}
	{ldw t, sp[S_FILTERED_2]; add a, a, t}
	{ldw s, sp[S_FILTERED_3];}
	std s, t, b[a]

#if FRAME_SIZE_LOG2
	//reset the index if we have completed a frame
	ldw t, sp[S_AUDIO_POINTER_INDEX]
	{add t, t, 1; ldc s, FRAME_SIZE_LOG2}
	zext t, s
	stw t, sp[S_AUDIO_POINTER_INDEX];
	bt t, ds_loop
#endif

	//buffer exchange
	outct res[c_output], 8 //WARNING: do not change this
	in t, res[c_output]
	{stw t, sp[S_AUDIO_POINTER]}
	bu ds_loop


.tmp_decimate_to_pcm_4ch_48KHz:
	.size	decimate_to_pcm_4ch_48KHz, .tmp_decimate_to_pcm_4ch_48KHz-decimate_to_pcm_4ch_48KHz
	.align	4
	.cc_bottom decimate_to_pcm_4ch_48KHz.function

	.set	decimate_to_pcm_4ch_48KHz.nstackwords,NSTACKWORDS
	.globl	decimate_to_pcm_4ch_48KHz.nstackwords
	.set	decimate_to_pcm_4ch_48KHz.maxcores,1
	.globl	decimate_to_pcm_4ch_48KHz.maxcores
	.set	decimate_to_pcm_4ch_48KHz.maxtimers,0
	.globl	decimate_to_pcm_4ch_48KHz.maxtimers
	.set	decimate_to_pcm_4ch_48KHz.maxchanends,0
	.globl	decimate_to_pcm_4ch_48KHz.maxchanends
