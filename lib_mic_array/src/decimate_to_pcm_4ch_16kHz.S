	.section	.dp.data,"awd",@progbits
	.text
	.cc_top decimate_to_pcm_4ch_16kHz.function
	.globl	decimate_to_pcm_4ch_16kHz
	.align	4
	.type	decimate_to_pcm_4ch_16kHz,@function

#include "defines.h"

//r0 to r7 are general purpose

#define c_input			      r8
#define p_integral		      r9
#define s			          r10
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
	ldaw r2, sp[S_SECOND_STAGE_OUTPUT_OFFSET];\
	stw r1, r2[OUTPUT]


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

#define INIT_DATA_LOOP(DATA, label) \
	ldaw r1, sp[S_FIR_OFFSET];\
	ldc r4, DATA;\
	ldaw r1, r1[r4];\
	ldc r4, 0;\
	label:stw r0, r1[r4];\
	ldc r3, COEFS_PER_PHASE;\
	ldaw r0, r0[r3];\
	add r4, r4, 1;\
	eq r3, r4, t;\
	bf r3, label


#define S_INPUT_OFFSET 0 //this one needs to be first
#define S_D_INPUT_0	0
#define S_D_INPUT_1 1
#define S_D_INPUT_2 2
#define S_D_INPUT_3 3
#define S_D_INPUT_4 4
#define S_D_INPUT_5 5
#define S_D_INPUT_6 6
#define S_D_INPUT_7 7

#define S_INTEGRAL_OFFSET (S_INPUT_OFFSET+16)
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

#define S_COMB_OFFSET (S_INTEGRAL_OFFSET+24)
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

#define S_DC_ELIMINATE_OFFSET (S_COMB_OFFSET+24)
#define S_D_PREV_XY_0 0
#define S_D_PREV_XY_1 1
#define S_D_PREV_XY_2 2
#define S_D_PREV_XY_3 3

#define S_SECOND_STAGE_OUTPUT_OFFSET (S_DC_ELIMINATE_OFFSET+8)
#define S_D_SECOND_STAGE_OUTPUT_01 0
#define S_SECOND_STAGE_OUTPUT_0 0
#define S_SECOND_STAGE_OUTPUT_1 1
#define S_D_SECOND_STAGE_OUTPUT_23 1
#define S_SECOND_STAGE_OUTPUT_2 2
#define S_SECOND_STAGE_OUTPUT_3 3
#define SECOND_STAGE_OUTPUT_STACK_SIZE 4

//fir decimator
#define S_FIR_OFFSET (S_SECOND_STAGE_OUTPUT_OFFSET+SECOND_STAGE_OUTPUT_STACK_SIZE)
#define S_SUM_0 		0
#define S_D_SUM_0 		0
#define S_SUM_1 		2
#define S_D_SUM_1 		1
#define S_SUM_2 		4
#define S_D_SUM_2 		2
#define S_SUM_3 		6
#define S_D_SUM_3 		3
#define S_FIR_PHASE		8
#define S_FIR_UNUSED	9
#define S_COEFS			10
#define S_DATA_0		(S_COEFS  + MAX_DECIMATION_FACTOR)
#define S_DATA_1		(S_DATA_0 + MAX_DECIMATION_FACTOR)
#define S_DATA_2		(S_DATA_1 + MAX_DECIMATION_FACTOR)
#define S_DATA_3		(S_DATA_2 + MAX_DECIMATION_FACTOR)
#define FIR_STACK_SIZE  (S_DATA_3 + MAX_DECIMATION_FACTOR)

//frame
#define S_FRAME_OFFSET (S_FIR_OFFSET+FIR_STACK_SIZE)
#define S_D_AUDIO_POINTER_AND_INDEX 0
#define S_AUDIO_POINTER 		0	//must bd double word aligned
#define S_AUDIO_POINTER_INDEX 	1
#define S_C_OUTPUT				2
#define S_FRAME_SIZE_LOG2		3
#define S_FRAME_MIN				4
#define S_FRAME_MAX				5
#define FRAME_STACK_SIZE		6

#define S_SETTINGS_OFFSET (S_FRAME_OFFSET+FRAME_STACK_SIZE)	//TODO finish the fir stack
#define S_WINDOWING_ENABLED 			0
#define S_INDEX_BITREVERSING_ENABLED 	1
#define S_DC_OFFSET_REMOVAL_ENABLED 	2
#define S_DECIMATION_FACTOR 			3
#define S_SETTINGS_SIZE					4

#define NSTACKWORDS (S_SETTINGS_OFFSET + S_SETTINGS_SIZE)

/*
void decimate_to_pcm_4ch_16kHz(
        streaming chanend c_4x_pdm_mic,		//r0
        streaming chanend c_frame_output,	//r1
        decimator_config config); 			//r2
*/

decimate_to_pcm_4ch_16kHz:
.align 8
.issue_mode dual

	//extend the stack
	DUALENTSP_lu6 NSTACKWORDS

	mov c_input, r0

	//set the integral pointer
	ldaw p_integral, sp[S_INTEGRAL_OFFSET]


	//store c_output off to the stack
	ldaw t, sp[S_FRAME_OFFSET]
	stw r1, t[S_C_OUTPUT]

	//copy the setting out of the struct
	ldaw r0, sp[S_FRAME_OFFSET]

	ldw t, r2[0] //frame_size_log2
	stw t, r0[S_FRAME_SIZE_LOG2]

	ldaw r0, sp[S_SETTINGS_OFFSET]

	ldw t, r2[1] //apply_dc_offset
	stw t, r0[S_DC_OFFSET_REMOVAL_ENABLED]

	ldw t, r2[2] //index_bit_reversal
	stw t, r0[S_INDEX_BITREVERSING_ENABLED]

	ldw t, r2[3] //windowing_function
	stw t, r0[S_WINDOWING_ENABLED]

	ldw t, r2[4] //deciamtion factor
	stw t, r0[S_DECIMATION_FACTOR]

	//Copy the coefficient pointer over
setup_coefs:
	ldaw r1, sp[S_FIR_OFFSET]
	ldaw r1, r1[S_COEFS]
	{ldw r0, r2[5]; ldc r4, 0} //coef pointer
	coef_init_loop:
		ldw r3, r0[r4]
		stw r3, r1[r4]
		add r4, r4, 1
		eq r3, r4, t
		bf r3, coef_init_loop

	ldw r0, r2[6] //data pointer
	INIT_DATA_LOOP(S_DATA_0, data_0_init_loop)
	INIT_DATA_LOOP(S_DATA_1, data_1_init_loop)
	INIT_DATA_LOOP(S_DATA_2, data_2_init_loop)
	INIT_DATA_LOOP(S_DATA_3, data_3_init_loop)

	//TODO mic gain compensation


	/*
	Initialise the stack regions:
		- 	S_INPUT
		- 	S_INTEGRAL
		- 	S_COMB
		- 	S_DC_ELIMINATE
		- 	S_SECOND_STAGE_OUTPUT
	*/
setup_stack_init:
	ldc r1, ((S_FIR_OFFSET + S_COEFS)/2) - 1
	{ldaw r3, sp[0];ldc t, 0}
init_loop:
	std t, t, r3[r1]
	{bt r1, init_loop ; sub r1, r1, 1}

init_fir_phase:
	ldaw t, sp[S_FIR_OFFSET]
	ldc r1, 0
	stw r1, t[S_FIR_PHASE]

init_frame_index:
	ldaw t, sp[S_FRAME_OFFSET]
	ldc r1, 0
	stw r1, t[S_AUDIO_POINTER_INDEX]

get_frame_pointer:
	ldaw t, sp[S_FRAME_OFFSET]
	ldw r2, t[S_C_OUTPUT]
    in r1, res[r2]
	stw r1, t[S_AUDIO_POINTER]

ds_loop:
input_sample_0:
	INPUT(S_D_INPUT_0)  //comb and dc eliminate all mics
		comb0:
		COMB(S_SECOND_STAGE_OUTPUT_0, 5, 0, 1, 2)	//make sure these input fields match the intergator outputs
		comb1:
		COMB(S_SECOND_STAGE_OUTPUT_1, 11, 3, 4, 5)
		comb2:
		COMB(S_SECOND_STAGE_OUTPUT_2, 17, 6, 7, 8)
		comb3:
		COMB(S_SECOND_STAGE_OUTPUT_3, 23, 9, 10, 11)
		check_dc_offset_removal:
		ldaw t, sp[S_SETTINGS_OFFSET]
		ldw t, t[S_DC_OFFSET_REMOVAL_ENABLED]
		bf t, skip_dc_offset_removal
			dc_offset_removal_0:
			DC_OFFSET_REMOVAL(S_D_PREV_XY_0, S_SECOND_STAGE_OUTPUT_0);
			dc_offset_removal_1:
			DC_OFFSET_REMOVAL(S_D_PREV_XY_1, S_SECOND_STAGE_OUTPUT_1);
			dc_offset_removal_2:
			DC_OFFSET_REMOVAL(S_D_PREV_XY_2, S_SECOND_STAGE_OUTPUT_2);
			dc_offset_removal_3:
			DC_OFFSET_REMOVAL(S_D_PREV_XY_3, S_SECOND_STAGE_OUTPUT_3);
		skip_dc_offset_removal:

input_sample_1:
	INPUT(S_D_INPUT_1) //fir mic 0
	/*
fir0:
	ldaw t, sp[S_FIR_OFFSET]
	{ldw r1, t[S_FIR_PHASE]; ldc r0, S_DATA_0}
	ldw r7, t[r0]
	{ldw r7, r7[r1];}
	ldw r6, t[S_COEFS]
	{ldw r6, r6[r1];}
	{ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]}
	ldw r5, r0[S_SECOND_STAGE_OUTPUT_0]
	ldd r1, r0, t[S_D_SUM_0]
	{bl fir_impl}
	ldaw t, sp[S_FIR_OFFSET]
	std r1, r0, t[S_D_SUM_0]
	*/
input_sample_2:
	INPUT(S_D_INPUT_2) //fir mic 1
	/*
	ldaw t, sp[S_FIR_OFFSET]
	{ldw r1, t[S_FIR_PHASE]; ldc r0, S_DATA_1}
	ldw r7, t[r0]
	{ldw r7, r7[r1]; ldc r0, S_COEFS}
	ldw r6, t[r0]
	{ldw r6, r6[r1];}
	{ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]}
	ldw r5, r0[S_SECOND_STAGE_OUTPUT_1]
	ldd r1, r0, t[S_D_SUM_1]
	bl fir_impl
	ldaw t, sp[S_FIR_OFFSET]
	std r1, r0, t[S_D_SUM_1]
	*/

input_sample_3:
	INPUT(S_D_INPUT_3) //fir mic 2
	/*
	ldaw t, sp[S_FIR_OFFSET]
	{ldw r1, t[S_FIR_PHASE]; ldc r0, S_DATA_2}
	ldw r7, t[r0]
	{ldw r7, r7[r1]; ldc r0, S_COEFS}
	ldw r6, t[r0]
	{ldw r6, r6[r1];}
	{ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]}
	ldw r5, r0[S_SECOND_STAGE_OUTPUT_2]
	ldd r1, r0, t[S_D_SUM_2]
	bl fir_impl
	ldaw t, sp[S_FIR_OFFSET]
	std r1, r0, t[S_D_SUM_2]
	*/

input_sample_4:
	INPUT(S_D_INPUT_4) //fir mic 3
	/*
	ldaw t, sp[S_FIR_OFFSET]
	{ldw r1, t[S_FIR_PHASE]; ldc r0, S_DATA_3}
	ldw r7, t[r0]
	{ldw r7, r7[r1]; ldc r0, S_COEFS}
	ldw r6, t[r0]
	{ldw r6, r6[r1];}
	{ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]}
	ldw r5, r0[S_SECOND_STAGE_OUTPUT_3]
	ldd r1, r0, t[S_D_SUM_3]
	bl fir_impl
	ldaw t, sp[S_FIR_OFFSET]
	std r1, r0, t[S_D_SUM_3]
	*/

input_sample_5:
	INPUT(S_D_INPUT_5)
/*
	//move all the fir outputs back into the second stage outputs
	ldaw r0, sp[S_FIR_OFFSET]
	ldaw r1, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
	ldw r2, r0[S_SUM_0+1]
	stw r2, r1[S_SECOND_STAGE_OUTPUT_0]
	ldw r2, r0[S_SUM_1+1]
	stw r2, r1[S_SECOND_STAGE_OUTPUT_1]
	ldw r2, r0[S_SUM_2+1]
	stw r2, r1[S_SECOND_STAGE_OUTPUT_2]
	ldw r2, r0[S_SUM_3+1]
	stw r2, r1[S_SECOND_STAGE_OUTPUT_3]
*/
	//TODO update the min and max vals

input_sample_6:
	INPUT(S_D_INPUT_6)

	ldaw r0, sp[S_FIR_OFFSET]
	ldw r2, r0[S_FIR_PHASE]
	add r2, r2, 1
	ldaw r1, sp[S_SETTINGS_OFFSET]
	ldw r1, r1[S_DECIMATION_FACTOR]
	eq r1, r1, r2
	bt r1, save_sample
	next_phase:
	stw r2, r0[S_FIR_PHASE]
	bu input_sample_7
	save_sample:

		ldaw r0, sp[S_FRAME_OFFSET]
		ldw r2, r0[S_FRAME_SIZE_LOG2]
		ldaw r1, sp[S_SETTINGS_OFFSET]
		ldw r1, r1[S_INDEX_BITREVERSING_ENABLED]
		bf r1, write_out_audio_frames
		write_out_fft_frames:
			ldaw r5, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			{ldw r1, r0[S_AUDIO_POINTER_INDEX]; ldc r3, 32}
			{bitrev r1, r1; sub r3, r3, r2}
			{shr r1, r1, r3;ldw r4, r0[S_AUDIO_POINTER]}
			ldd r3, t, r5[S_D_SECOND_STAGE_OUTPUT_01]
			std r3, t, r4[r1]
			{ldc r3, 1;nop}
			{shl r3, r3, r2;nop}
			{add r1, r1, r3;nop}
			ldd r3, t, r5[S_D_SECOND_STAGE_OUTPUT_23]
			std r3, t, r4[r1]
			bu inc_audio_index

		write_out_audio_frames:
			ldaw r5, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			ldd r3, r4, r0[S_D_AUDIO_POINTER_AND_INDEX]
			ldd r1, t, r5[S_D_SECOND_STAGE_OUTPUT_01]
			ldaw r4, r4[r3]
			{ldc r3, 1; stw t, r4[0]}
			{shl r3, r3, r2; nop}
			stw r1, r4[r3]
			add r3, r3, r3
			ldd r1, t, r5[S_D_SECOND_STAGE_OUTPUT_23]
			stw t, r4[r3]
			{ldc r3, 3; nop}
			shl r3, r3, r2
			stw r1, r4[r3]

	inc_audio_index:
	    bf r2, exchange_buffers
			//reset the index if we have completed a frame
			ldw r1, r0[S_AUDIO_POINTER_INDEX]
			{add r1, r1, 1;}
			zext r1, r2
			stw r1, r0[S_AUDIO_POINTER_INDEX];
			bt r1, input_sample_7
	exchange_buffers:
		ldw r1, r0[S_C_OUTPUT]
		outct res[r1], 8 //WARNING: do not change this
		in r1, res[r1]
		{stw r1, r0[S_AUDIO_POINTER]}


input_sample_7:
	INPUT(S_D_INPUT_7)	//162 instruction per loop
		integrate_0:
		INTEGRATE(0, 0,  1,  2)	//39 inst
		integrate_1:
		INTEGRATE(1, 3,  4,  5) //39 inst
		integrate_2:
		INTEGRATE(2, 6,  7,  8) //39 inst
		integrate_3:
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
	.align	8
	.type	fir_impl,@function
	.issue_mode dual

#define DOUBLE_TAP(I)\
	ldd r2, t, r6[I];\
	maccs r1, r0, t, r5;\
	ldd r4, r3, r7[I];\
	maccs r1, r0, r2, r5;\
	std r3, r5, r7[I];\
	ldd r2, t, r6[I+1];\
	maccs r1, r0, t, r4;\
	ldd r5, r3, r7[I+1];\
	maccs r1, r0, r2, r3;\
	std r3, r4, r7[I+1]

/*
lo		0
hi		1
c0		t
c1		2
d0		3
d1		4
n		5
coefs	6
data	7
*/


.align 8
.issue_mode dual
fir_impl:
/*
	DOUBLE_TAP(0)
	DOUBLE_TAP(2)
	DOUBLE_TAP(4)
	DOUBLE_TAP(6)
	DOUBLE_TAP(8)
	DOUBLE_TAP(10)
	ldc t, 24*4
	{add r7, r7, t; add r6, r6, t}
	DOUBLE_TAP(0)
	DOUBLE_TAP(2)
	DOUBLE_TAP(4)
	DOUBLE_TAP(6)
	DOUBLE_TAP(8)
	DOUBLE_TAP(10)
	//TODO add the most possible - try to get to 60
	*/
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
