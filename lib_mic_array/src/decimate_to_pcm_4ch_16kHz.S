	.section	.dp.data,"awd",@progbits
	.text
	.cc_top decimate_to_pcm_4ch_16kHz.function
	.globl	decimate_to_pcm_4ch_16kHz
	.align	4
	.type	decimate_to_pcm_4ch_16kHz,@function

#include "defines.h"

//r0 to r7 are general purpose

#define c_input			      r8
#define frame_size_log2		  r9
#define p_integral			  r10
#define t                     r11

#define DC_OFFSET_REMOVAL(PREV_XY, COMB_OUTPUT) \
	ldaw r3, sp[S_DC_ELIMINATE_OFFSET];\
	ldd r1, r0, r3[PREV_XY];\
	ashr r2, r1, 8;\
	{sub r1, r1, r2; nop};\
	{sub r1, r1, r0; ldw r2, sp[COMB_OUTPUT]};\
	{add r1, r1, r2; nop};\
	{stw r1, sp[COMB_OUTPUT]};\
	std r1, r2, r3[PREV_XY];

#define INPUT(S) \
	in r0, res[c_input];\
	in r1, res[c_input];\
	std r1, r0, sp[S];

#define COMB(OUTPUT, INPUT, OFF_0, OFF_1, OFF_2) \
	{ldc r1, INPUT;ldaw r0, sp[S_COMB_OFFSET]};\
	{ldaw r1, p_integral[r1]};\
    ldd r2, r3, r0[OFF_0];\
	{sub r1, r1, r2 ; mov r2, r1};\
	{sub r1, r1, r3 ; mov r3, r1};\
	std r2, r3, r0[OFF_0];\
    ldd r2, r3, r0[OFF_1];\
	{sub r1, r1, r2 ; mov r2, r1};\
	{sub r1, r1, r3 ; mov r3, r1};\
	std r2, r3, r0[OFF_1];\
    ldd r2, r3, r0[OFF_2];\
	{sub r1, r1, r2 ; mov r2, r1};\
	{sub r1, r1, r3 ; mov r3, r1};\
	std r2, r3, r0[OFF_2];\
	stw r1, sp[OUTPUT]


//TODO make sure all input have been masked already
#define INTEGRATE(MICROPHONE, OFF_0, OFF_1, OFF_2)\
	ldd r1, r0, p_integral[OFF_0];\
	ldd r3, r2, p_integral[OFF_1];\
	ldd r5, r4, p_integral[OFF_2];\
	{ldc r6, MICROPHONE; ldaw r7, sp[S_INPUT_OFFSET]};\
	{ld8u t, r7[r6];   add r6, r6, 4};\
	{ld8u t, r7[r6];  add r0, r0, t};\
	{add r1, r1, r0; add r0, r0, t};\
	{add r2, r2, r1; add r1, r1, r0};\
	{add r3, r3, r2; add r2, r2, r1};\
	{add r4, r4, r3; add r3, r3, r2};\
	{add r5, r5, r4; add r4, r4, r3};\
	{add r6, r6, 4;  add r5, r5, r4};\
	{ld8u t, r7[r6];  add r6, r6, 4};\
	{ld8u t, r7[r6];  add r0, r0, t};\
	{add r1, r1, r0; add r0, r0, t};\
	{add r2, r2, r1; add r1, r1, r0};\
	{add r3, r3, r2; add r2, r2, r1};\
	{add r4, r4, r3; add r3, r3, r2};\
	{add r5, r5, r4; add r4, r4, r3};\
	{add r6, r6, 4;  add r5, r5, r4};\
	{ld8u t, r7[r6];  add r6, r6, 4};\
	{ld8u t, r7[r6];  add r0, r0, t};\
	{add r1, r1, r0; add r0, r0, t};\
	{add r2, r2, r1; add r1, r1, r0};\
	{add r3, r3, r2; add r2, r2, r1};\
	{add r4, r4, r3; add r3, r3, r2};\
	{add r5, r5, r4; add r4, r4, r3};\
	{add r6, r6, 4;  add r5, r5, r4};\
	{ld8u t, r7[r6];  add r6, r6, 4};\
	{ld8u t, r7[r6];  add r0, r0, t};\
	{add r1, r1, r0; add r0, r0, t};\
	{add r2, r2, r1; add r1, r1, r0};\
	{add r3, r3, r2; add r2, r2, r1};\
	{add r4, r4, r3; add r3, r3, r2};\
	{add r5, r5, r4; add r4, r4, r3};\
	{              ; add r5, r5, r4};\
	std r1, r0, p_integral[OFF_0];\
	std r3, r2, p_integral[OFF_1];\
	std r5, r4, p_integral[OFF_2]

#define S_INPUT_OFFSET 0 //this one needs to be first
#define S_D_INPUT_0	0
#define S_D_INPUT_1 1
#define S_D_INPUT_2 2
#define S_D_INPUT_3 3
#define S_D_INPUT_4 4
#define S_D_INPUT_5 5
#define S_D_INPUT_6 6
#define S_D_INPUT_7 7

#define S_INTEGRAL_OFFSET 16
#define S_D_INT_0_01 0
#define S_D_INT_0_23 1
#define S_D_INT_0_45 2
#define S_D_INT_1_01 3
#define S_D_INT_1_23 4
#define S_D_INT_1_45 5
#define S_D_INT_2_01 6
#define S_D_INT_2_23 7
#define S_D_INT_2_45 8
#define S_D_INT_3_01 9
#define S_D_INT_3_23 10
#define S_D_INT_3_45 11

#define S_COMB_OFFSET (16+24)
#define S_D_COMB_0_01 0
#define S_D_COMB_0_23 1
#define S_D_COMB_0_45 2
#define S_D_COMB_1_01 3
#define S_D_COMB_1_23 4
#define S_D_COMB_1_45 5
#define S_D_COMB_2_01 6
#define S_D_COMB_2_23 7
#define S_D_COMB_2_45 8
#define S_D_COMB_3_01 9
#define S_D_COMB_3_23 10
#define S_D_COMB_3_45 11

#define S_DC_ELIMINATE_OFFSET (16+24+24)
#define S_D_PREV_XY_0 0
#define S_D_PREV_XY_1 1
#define S_D_PREV_XY_2 2
#define S_D_PREV_XY_3 3

#define S_SECOND_STAGE_OUTPUT_0 0 //TODO set these right
#define S_SECOND_STAGE_OUTPUT_1 1
#define S_SECOND_STAGE_OUTPUT_2 2
#define S_SECOND_STAGE_OUTPUT_3 3

//frame
#define S_AUDIO_POINTER 20
#define S_AUDIO_POINTER_INDEX 21
#define S_D_AUDIO_POINTER_AND_INDEX 10
#define S_FRAME_SIZE_LOG2


//for the settings
#define WINDOWING_ENABLED 22
#define INDEX_BITREVERSING_ENABLED 23
#define DC_OFFSET_REMOVAL_ENABLED 24
#define DECIMATION_FACTOR 25

#define STACK 32

#define NSTACKWORDS  128

decimate_to_pcm_4ch_16kHz:
.align 8
.issue_mode dual

	//extend the stack
	DUALENTSP_lu6 NSTACKWORDS

	//copy the setting out of the struct
	ldw frame_size_log2, r2[0] //frame_size_log2

	ldw t, r2[1] //apply_dc_offset
	stw t, sp[DC_OFFSET_REMOVAL_ENABLED]

	ldw t, r2[2] //index_bit_reversal
	stw t, sp[INDEX_BITREVERSING_ENABLED]

	ldw t, r2[3] //windowing_function
	stw t, sp[WINDOWING_ENABLED]

	ldw t, r2[4] //deciamtion factor
	stw t, sp[DECIMATION_FACTOR]
	//TODO save off the data and coefs

	ldc t, 0

	//init all arrays to zero

	//stw t, sp[S_AUDIO_POINTER_INDEX]

	//grab the first pointer
    //in t, res[c_output]
	//stw t, sp[S_AUDIO_POINTER]

ds_loop:
	INPUT(S_D_INPUT_0)  //comb and dc eliminate all mics
		COMB(S_SECOND_STAGE_OUTPUT_0, 5, 0, 1, 2)
		COMB(S_SECOND_STAGE_OUTPUT_1, 11, 3, 4, 5)
		COMB(S_SECOND_STAGE_OUTPUT_2, 17, 6, 7, 8)
		COMB(S_SECOND_STAGE_OUTPUT_3, 23, 9, 10, 11)
		ldw t, sp[DC_OFFSET_REMOVAL_ENABLED]
		bf t, skip_dc_offset_removal
			DC_OFFSET_REMOVAL(S_D_PREV_XY_0, S_SECOND_STAGE_OUTPUT_0);
			DC_OFFSET_REMOVAL(S_D_PREV_XY_1, S_SECOND_STAGE_OUTPUT_1);
			DC_OFFSET_REMOVAL(S_D_PREV_XY_2, S_SECOND_STAGE_OUTPUT_2);
			DC_OFFSET_REMOVAL(S_D_PREV_XY_3, S_SECOND_STAGE_OUTPUT_3);
		skip_dc_offset_removal:

	INPUT(S_D_INPUT_1) //fir mic 0
	/*
	ldw index, sp[S_INDEX]
	ldw data, sp[S_DATA_0]
	ldw data, data[index]
	ldw coefs, sp[S_COEFS]
	ldw coefs, coefs[index]
	ldw n, sp[S_SECOND_STAGE_OUTPUT_0]
	ldd hi, lo, sp[S_SUM_0]
	bl fir_impl
	std hi, lo, sp[S_SUM_0]
*/
	INPUT(S_D_INPUT_2) //fir mic 1
	/*
	ldw index, sp[S_INDEX]
	ldw data, sp[S_DATA_1]
	ldw data, data[index]
	ldw coefs, sp[S_COEFS]
	ldw coefs, coefs[index]
	ldw n, sp[S_SECOND_STAGE_OUTPUT_1]
	ldd hi, lo, sp[S_SUM_1]
	bl fir_impl
	std hi, lo, sp[S_SUM_1]
*/

	INPUT(S_D_INPUT_3) //fir mic 2
	/*
	ldw index, sp[S_INDEX]
	ldw data, sp[S_DATA_2]
	ldw data, data[index]
	ldw coefs, sp[S_COEFS]
	ldw coefs, coefs[index]
	ldw n, sp[S_SECOND_STAGE_OUTPUT_2]
	ldd hi, lo, sp[S_SUM_2]
	bl fir_impl
	std hi, lo, sp[S_SUM_2]

*/
	INPUT(S_D_INPUT_4) //fir mic 3
	/*
	ldw index, sp[S_INDEX]
	ldw data, sp[S_DATA_3]
	ldw data, data[index]
	ldw coefs, sp[S_COEFS]
	ldw coefs, coefs[index]
	ldw n, sp[S_SECOND_STAGE_OUTPUT_3]
	ldd hi, lo, sp[S_SUM_3]
	bl fir_impl
	std hi, lo, sp[S_SUM_3]
*/

	INPUT(S_D_INPUT_5)

	//sort the index out

	INPUT(S_D_INPUT_6)

	//save output to frame(every one in three)



	INPUT(S_D_INPUT_7)	//162 instruction per loop
		INTEGRATE(0, 0,  1,  2)	//39 inst
		INTEGRATE(1, 3,  4,  5) //39 inst
		INTEGRATE(2, 6,  7,  8) //39 inst
		INTEGRATE(3, 9, 10, 11) //39 inst
	bl ds_loop

.tmp_decimate_to_pcm_4ch_16kHz:
	.size	decimate_to_pcm_4ch_16kHz, .tmp_decimate_to_pcm_4ch_16kHz-decimate_to_pcm_4ch_16kHz
	.align	4
	.cc_bottom decimate_to_pcm_4ch_16kHz.function

	.set	decimate_to_pcm_4ch_16kHz.nstackwords,NSTACKWORDS
	.globl	decimate_to_pcm_4ch_16kHz.nstackwords
	.set	decimate_to_pcm_4ch_16kHz.maxcores,1
	.globl	decimate_to_pcm_4ch_16kHz.maxcores
	.set	decimate_to_pcm_4ch_16kHz.maxtimers,0
	.globl	decimate_to_pcm_4ch_16kHz.maxtimers
	.set	decimate_to_pcm_4ch_16kHz.maxchanends,0
	.globl	decimate_to_pcm_4ch_16kHz.maxchanends


	.cc_top fir_impl.function
	.globl	fir_impl
	.align	4
	.type	fir_impl,@function



#define DOUBLE_TAP(I)\
	nop
	/*
	ldd c1, c0, coefs[I];\
	maccs hi, lo, c0, n;\
	ldd d1, d0, data[I];\
	maccs hi, lo, c0, n;\
	std d0, n, data[I];\
	ldd c1, c0, coefs[I+1];\
	maccs hi, lo, c0, d1;\
	ldd n, d0, data[I+1];\
	maccs hi, lo, c0, d0;\
	std d0, d1, data[I+1]
	*/


fir_impl:
.align 8
.issue_mode dual
	DOUBLE_TAP(0)
	DOUBLE_TAP(2)
	DOUBLE_TAP(4)
	DOUBLE_TAP(6)
	DOUBLE_TAP(8)
	DOUBLE_TAP(10)
	//ldaw data, data[24]
	//ldaw coefs, coefs[24]
	DOUBLE_TAP(0)
	DOUBLE_TAP(2)
	retsp 0
.tmp_fir_impl:
	.size	fir_impl, .tmp_fir_impl-fir_impl
	.align	4
	.cc_bottom fir_impl.function

	.set	fir_impl.nstackwords,0
	.globl	fir_impl.nstackwords
	.set	fir_impl.maxcores,1
	.globl	fir_impl.maxcores
	.set	fir_impl.maxtimers,0
	.globl	fir_impl.maxtimers
	.set	fir_impl.maxchanends,0
	.globl	fir_impl.maxchanends
