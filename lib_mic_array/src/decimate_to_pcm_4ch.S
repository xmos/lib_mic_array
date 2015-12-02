// Copyright (c) 2015, XMOS Ltd, All rights reserved
	.section	.dp.data,"awd",@progbits
	.text
	.cc_top decimate_to_pcm_4ch.function
	.globl	decimate_to_pcm_4ch
	.align	4
	.type	decimate_to_pcm_4ch,@function

.xtacommand "add exclusion configure_ep","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_0_ep input_sample_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_1_ep input_sample_2_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_2_ep input_sample_3_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_3_ep input_sample_4_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_4_ep input_sample_5_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_5_ep input_sample_6_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_6_ep input_sample_7_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_sample_7_ep input_sample_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__

#include "mic_array_defines.h"

#define EXCHANGE_BUFFERS 0
#define CONFIGURE_DECIMATOR 1

//r0 to r7 are general purpose

#define c_input			      r8
#define p_integral		      r9
#define s			          r10
#define t                     r11

#define MIN_MAX(MIN, MAX, P) \
	ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET];\
	ldd r1, r2, r0[S_D_SECOND_STAGE_OUTPUT_01];\
	ldd r3, r4, r0[S_D_SECOND_STAGE_OUTPUT_23];\
	ldaw r0, sp[S_FRAME_OFFSET];\
	ldw r5, r0[MAX];\
	lss r6, r5, r1;\
	{bf r6, max_skip0 ## P; lss r6, r5, r2};\
	{mov r5, r1; lss r6, r1, r2};\
	max_skip0 ## P: {bf r6, max_skip1 ## P; lss r6, r5, r3};\
	{mov r5, r2; lss r6, r2, r3};\
	max_skip1 ## P: {bf r6, max_skip2 ## P; lss r6, r5, r4};\
	{mov r5, r3; lss r6, r3, r4};\
	max_skip2 ## P: {bf r6, max_skip3 ## P; nop};\
	{mov r5, r4; nop};\
	max_skip3 ## P: stw r5, r0[MAX];\
	ldw r5, r0[MIN];\
	lss r6, r5, r1;\
	{bt r6, min_skip0 ## P; lss r6, r5, r2};\
	{mov r5, r1; lss r6, r1, r2};\
	min_skip0 ## P: {bt r6, min_skip1 ## P; lss r6, r5, r3};\
	{mov r5, r2; lss r6, r2, r3};\
	min_skip1 ## P: {bt r6, min_skip2 ## P; lss r6, r5, r4};\
	{mov r5, r3; lss r6, r3, r4};\
	min_skip2 ## P: {bt r6, min_skip3 ## P; nop};\
	{mov r5, r4; nop};\
	min_skip3 ## P: stw r5, r0[MIN]



#define DC_OFFSET_REMOVAL(PREV_Y, PREV_X, COMB_OUTPUT) \
	ldd r1, r0, r3[PREV_Y];\
	{shl r2, r1, 24; ldc r5, 0};\
	lsub r2, r0, r0, r2, r5;\
	ashr r5, r1, 8;\
	lsub r2, r1, r1, r5, r2;\
	{ldw r2, r4[COMB_OUTPUT]; nop};\
	{add r1, r1, r2; ldw r5, r3[PREV_X]};\
	{sub r1, r1, r5; stw r2, r3[PREV_X]};\
	{stw r1, r4[COMB_OUTPUT]};\
	std r1, r0, r3[PREV_Y];

#define INPUT(S) \
	in r0, res[c_input];\
	in r1, res[c_input];\
	std r1, r0, sp[S];

#define COMB(OUTPUT, INPUT, OFF_0, OFF_1, OFF_2) \
	{ldc r1, INPUT;ldaw r0, sp[S_COMB_OFFSET]};\
	{ldw r1, p_integral[r1]};\
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

#define INTEGRATE_ITT() \
	{ld8u t, r7[r6]; add r6, r6, 4};\
	{ld8u t, r7[r6]; add r0, r0, t};\
	{add r1, r1, r0; add r0, r0, t};\
	{add r2, r2, r1; add r1, r1, r0};\
	{add r3, r3, r2; add r2, r2, r1};\
	{add r4, r4, r3; add r3, r3, r2};\
	{add r5, r5, r4; add r4, r4, r3};\
	{add r6, r6, 4;  add r5, r5, r4};\

#define INTEGRATE(MICROPHONE, OFF_0, OFF_1, OFF_2)\
	ldd r1, r0, p_integral[OFF_0];\
	ldd r3, r2, p_integral[OFF_1];\
	{ldc r6, MICROPHONE; ldaw r7, sp[S_INPUT_OFFSET]};\
	ldd r5, r4, p_integral[OFF_2];\
	INTEGRATE_ITT();\
	INTEGRATE_ITT();\
	INTEGRATE_ITT();\
	INTEGRATE_ITT();\
	INTEGRATE_ITT();\
	INTEGRATE_ITT();\
	INTEGRATE_ITT();\
	INTEGRATE_ITT();\
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

#define FIR(DATA, SECOND_STAGE_OUTPUT, SUM)\
	ldaw t, sp[S_FIR_OFFSET];\
	{ldw r1, t[S_FIR_PHASE]; ldc r0, DATA};\
	ldaw r7, t[r0];\
	ldw r7, r7[r1];\
	ldaw r6, t[S_COEFS];\
	ldw r6, r6[r1];\
	{ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]};\
	ldw r5, r0[SECOND_STAGE_OUTPUT];\
	ldd r1, r0, t[SUM];\
	{bl fir_impl};\
	ldaw t, sp[S_FIR_OFFSET];\
	std r1, r0, t[SUM];\

#define S_INPUT_OFFSET 0 //this one needs to be first
#define S_D_INPUT_0	0
#define S_D_INPUT_1 1
#define S_D_INPUT_2 2
#define S_D_INPUT_3 3
#define S_D_INPUT_4 4
#define S_D_INPUT_5 5
#define S_D_INPUT_6 6
#define S_D_INPUT_7 7
#define S_D_INPUT_TEMP 8
#define INPUT_STACK_SIZE 18

#define S_INTEGRAL_OFFSET (S_INPUT_OFFSET+INPUT_STACK_SIZE)
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
#define INTEGRAL_STACK_SIZE 24

#define S_COMB_OFFSET (S_INTEGRAL_OFFSET+INTEGRAL_STACK_SIZE)
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
#define COMB_STACK_SIZE 24

#define S_SECOND_STAGE_OUTPUT_OFFSET (S_COMB_OFFSET+COMB_STACK_SIZE)
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

#define S_DC_ELIMINATE_OFFSET (S_FIR_OFFSET+FIR_STACK_SIZE)
#define S_D_PREV_Y_0 0
#define S_D_PREV_Y_1 1
#define S_D_PREV_Y_2 2
#define S_D_PREV_Y_3 3
#define S_PREV_X_0   8
#define S_PREV_X_1   9
#define S_PREV_X_2   10
#define S_PREV_X_3   11
#define DC_ELIMINATE_STACK_SIZE 12

//frame
#define S_FRAME_OFFSET (S_DC_ELIMINATE_OFFSET+DC_ELIMINATE_STACK_SIZE)
#define S_D_AUDIO_POINTER_AND_INDEX_0 3
#define S_D_AUDIO_POINTER_AND_INDEX_1 4
#define S_D_FRAME_MIN_MAX_0       	  5
#define S_D_FRAME_MIN_MAX_1       	  6
#define S_C_OUTPUT				0
#define S_FRAME_SIZE_LOG2		1
#define S_FRAME_NUMBER			2	//should this be presistant between configs?
#define S_BUFFER_COUNT          3
#define S_METADATA_POINTER_0    4
#define S_METADATA_POINTER_1    5
#define S_AUDIO_POINTER_0 		    6	//must be double word aligned
#define S_AUDIO_POINTER_0_INDEX     7
#define S_AUDIO_POINTER_1 		    8	//must be double word aligned
#define S_AUDIO_POINTER_1_INDEX     9
#define S_FRAME_MIN_0				10   //must be double word aligned
#define S_FRAME_MAX_0				11
#define S_FRAME_MIN_1				12   //must be double word aligned
#define S_FRAME_MAX_1				13
#define FRAME_STACK_SIZE		14

#define S_MIC_CALIB_OFFSET (S_FRAME_OFFSET+FRAME_STACK_SIZE)
#define S_MIC_CALIB_0 		0
#define S_MIC_CALIB_1 		1
#define S_D_MIC_CALIB_01 	0
#define S_MIC_CALIB_2 		2
#define S_MIC_CALIB_3		3
#define S_D_MIC_CALIB_23 	1
#define MIC_CALIB_STACK_SIZE		4

#define S_SETTINGS_OFFSET (S_MIC_CALIB_OFFSET+MIC_CALIB_STACK_SIZE)
#define S_WINDOWING_ENABLED 			0
#define S_INDEX_BITREVERSING_ENABLED 	1
#define S_DC_OFFSET_REMOVAL_ENABLED 	2
#define S_DECIMATION_FACTOR 			3
#define S_MIC_GAIN_COMP		 			4

#define S_SETTINGS_SIZE					6

#define NSTACKWORDS (S_SETTINGS_OFFSET + S_SETTINGS_SIZE)

/*
void decimate_to_pcm_4ch(
        streaming chanend c_4x_pdm_mic,		//r0
        streaming chanend c_frame_output); 	//r1
*/

decimate_to_pcm_4ch:
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
	ldc r1, 0
	stw r1, t[S_FRAME_NUMBER]

	ldaw r0, sp[S_FRAME_OFFSET]
	ldw r1, r0[S_C_OUTPUT]
	//wait for the decimator_configure to send us the configuration

	outct res[r1], 8		//we say we are ready
	inct r2, res[r1]		//they say CONFIGURE_DECIMATOR
	//cry if r2 != CONFIGURE_DECIMATOR

configure:	//This is the entry point if comming from a reconfigure

	in r2, res[r1]		//get the pointer to the decimator_config
	ldw r3, r2[0];		//r3 is the pointer to the decimator_config_common

	//copy the setting out of the struct
	ldaw r0, sp[S_FRAME_OFFSET]
	ldw t, r3[0] //frame_size_log2
	stw t, r0[S_FRAME_SIZE_LOG2]

	ldaw r0, sp[S_SETTINGS_OFFSET]

	ldw t, r3[1] //apply_dc_offset
	stw t, r0[S_DC_OFFSET_REMOVAL_ENABLED]

	ldw t, r3[2] //index_bit_reversal
	stw t, r0[S_INDEX_BITREVERSING_ENABLED]

	ldw t, r3[3] //windowing_function
	stw t, r0[S_WINDOWING_ENABLED]

	ldw t, r3[6]	//apply mic gain compensation
	stw t, r0[S_MIC_GAIN_COMP]

	ldw t, r3[4] //deciamtion factor
	stw t, r0[S_DECIMATION_FACTOR]

	//Copy the coefficient pointer over
setup_coefs:
	ldaw r1, sp[S_FIR_OFFSET]
	ldaw r1, r1[S_COEFS]
	{ldw r0, r3[5]; ldc r4, 0} //coef pointer
	coef_init_loop:
		stw r0, r1[r4]
		ldc r5, COEFS_PER_PHASE
		ldaw r0, r0[r5]
		add r4, r4, 1
		eq r5, r4, t
		bf r5, coef_init_loop

	ldw r0, r2[1] //data pointer
	INIT_DATA_LOOP(S_DATA_0, data_0_init_loop)
	INIT_DATA_LOOP(S_DATA_1, data_1_init_loop)
	INIT_DATA_LOOP(S_DATA_2, data_2_init_loop)
	INIT_DATA_LOOP(S_DATA_3, data_3_init_loop)

load_mic_gain_calib:
	ldaw r1, sp[S_MIC_CALIB_OFFSET]
	ldw r0, r2[2]
	stw r0, r1[S_MIC_CALIB_0]
	ldw r0, r2[3]
	stw r0, r1[S_MIC_CALIB_1]
	ldw r0, r2[4]
	stw r0, r1[S_MIC_CALIB_2]
	ldw r0, r2[5]
	stw r0, r1[S_MIC_CALIB_3]

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
	stw r1, t[S_AUDIO_POINTER_0_INDEX]
	std r1, r1, t[S_D_FRAME_MIN_MAX_0]
	std r1, r1, t[S_D_FRAME_MIN_MAX_1]

get_frame_pointer:
	ldaw t, sp[S_FRAME_OFFSET]
	ldw r2, t[S_C_OUTPUT]

	rx_buffer_count:
	in r5, res[r2]

	stw r5, t[S_BUFFER_COUNT]
    first_buffer:
    in r1, res[r2]
	stw r1, t[S_AUDIO_POINTER_0]
    in r1, res[r2]
	stw r1, t[S_METADATA_POINTER_0]

	sub r5, r5, 1
	bf r5, ds_loop
	second_buffer:
    in r1, res[r2]
	stw r1, t[S_AUDIO_POINTER_1]
    in r1, res[r2]
	stw r1, t[S_METADATA_POINTER_1]

ds_loop:
input_sample_0:
	INPUT(S_D_INPUT_TEMP)	//TODO check speed requirements
		integrate_2:
		INTEGRATE(2, 6,  7,  8) //78 inst
		integrate_3:
		INTEGRATE(3, 9, 10, 11) //78 inst
	ldd r1, r0, sp[S_D_INPUT_TEMP]
	std r1, r0, sp[S_D_INPUT_0]
input_sample_1:
	INPUT(S_D_INPUT_1)//comb and dc eliminate all mics
		comb0:
		COMB(S_SECOND_STAGE_OUTPUT_0, 5, 0, 1, 2)
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
			ldaw r3, sp[S_DC_ELIMINATE_OFFSET]
			ldaw r4, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			dc_offset_removal_0:
			DC_OFFSET_REMOVAL(S_D_PREV_Y_0, S_PREV_X_0, S_SECOND_STAGE_OUTPUT_0);
			dc_offset_removal_1:
			DC_OFFSET_REMOVAL(S_D_PREV_Y_1, S_PREV_X_1, S_SECOND_STAGE_OUTPUT_1);
			dc_offset_removal_2:
			DC_OFFSET_REMOVAL(S_D_PREV_Y_2, S_PREV_X_2, S_SECOND_STAGE_OUTPUT_2);
			dc_offset_removal_3:
			DC_OFFSET_REMOVAL(S_D_PREV_Y_3, S_PREV_X_3, S_SECOND_STAGE_OUTPUT_3);
			bu gain_compensation
		skip_dc_offset_removal:
		/*
			ldw r1, cp[g_cic_max]
			ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			ldd r3, r2, r0[S_D_SECOND_STAGE_OUTPUT_01]
			{sub r2, r2, r1; sub r3, r3, r1}
			std r3, r2, r0[S_D_SECOND_STAGE_OUTPUT_01]
			ldd r3, r2, r0[S_D_SECOND_STAGE_OUTPUT_23]
			{sub r2, r2, r1; sub r3, r3, r1}
			std r3, r2, r0[S_D_SECOND_STAGE_OUTPUT_23]
*/
		gain_compensation:
		//apply gain compensation
		ldaw r0, sp[S_SETTINGS_OFFSET]
		ldw r1, r0[S_MIC_GAIN_COMP]
		bf r1, input_sample_2
		apply_mic_gain_compensation:
			ldaw r0, sp[S_MIC_CALIB_OFFSET]
			ldd r2, r1, r0[S_D_MIC_CALIB_01]
			ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			ldd r4, r3, r0[S_D_SECOND_STAGE_OUTPUT_01]
			{ldc r5, 0; ldc r6, 0}
			maccs r5, r6, r1, r3
			{ldc r6, 0; ldc r1, 0}
			maccs r6, r1, r2, r4
			std r6, r5, r0[S_D_SECOND_STAGE_OUTPUT_01]
			ldaw r0, sp[S_MIC_CALIB_OFFSET]
			ldd r2, r1, r0[S_D_MIC_CALIB_23]
			ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			ldd r4, r3, r0[S_D_SECOND_STAGE_OUTPUT_23]
			{ldc r5, 0; ldc r6, 0}
			maccs r5, r6, r1, r3
			{ldc r6, 0; ldc r1, 0}
			maccs r6, r1, r2, r4
			std r6, r5, r0[S_D_SECOND_STAGE_OUTPUT_23]

input_sample_2:
	INPUT(S_D_INPUT_2)
	fir0:
	FIR(S_DATA_0, S_SECOND_STAGE_OUTPUT_0, S_D_SUM_0)

input_sample_3:
	INPUT(S_D_INPUT_3)
	fir1:
	FIR(S_DATA_1, S_SECOND_STAGE_OUTPUT_1, S_D_SUM_1)

input_sample_4:
	INPUT(S_D_INPUT_4)
	fir2:
	FIR(S_DATA_2, S_SECOND_STAGE_OUTPUT_2, S_D_SUM_2)

input_sample_5:
	INPUT(S_D_INPUT_5)
	fir3:
	FIR(S_DATA_3, S_SECOND_STAGE_OUTPUT_3, S_D_SUM_3)

input_sample_6:
	INPUT(S_D_INPUT_6)

	ldaw r0, sp[S_FIR_OFFSET]
	ldw r2, r0[S_FIR_PHASE]
	add r2, r2, 1
	ldaw r1, sp[S_SETTINGS_OFFSET]
	ldw r1, r1[S_DECIMATION_FACTOR]
	eq r1, r1, r2
	{bt r1, save_sample;ldc r1, 0}
	next_phase:
	stw r2, r0[S_FIR_PHASE]
	bu input_sample_7
	save_sample:

		//move all the fir outputs back into the second stage outputs
		ldc t, 0
		ldaw r1, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
		ldw r2, r0[S_SUM_0+1]
		std t, t, r0[S_D_SUM_0]
		stw r2, r1[S_SECOND_STAGE_OUTPUT_0]
		ldw r2, r0[S_SUM_1+1]
		std t, t, r0[S_D_SUM_1]
		stw r2, r1[S_SECOND_STAGE_OUTPUT_1]
		ldw r2, r0[S_SUM_2+1]
		std t, t, r0[S_D_SUM_2]
		stw r2, r1[S_SECOND_STAGE_OUTPUT_2]
		ldw r2, r0[S_SUM_3+1]
		std t, t, r0[S_D_SUM_3]
		stw r2, r1[S_SECOND_STAGE_OUTPUT_3]

		stw t, r0[S_FIR_PHASE]	//reset the FIR phase

		update_min_max:
		MIN_MAX(S_FRAME_MIN_0, S_FRAME_MAX_0, 0)

		//multiply the data values by the window function
		ldaw r0, sp[S_SETTINGS_OFFSET]
		ldw r1, r0[S_WINDOWING_ENABLED]
		bf r1, no_windowing
			ldaw r0, sp[S_FRAME_OFFSET]
			ldw r3, r0[S_FRAME_SIZE_LOG2]
			{mkmsk r4, r3; sub r3, r3, 1}
			{shr r3, r2, r3;ldw r2, r0[S_AUDIO_POINTER_0_INDEX]}
			bf r3, load_window_coef
			sub r2, r4, r2
			load_window_coef:
			ldw r1, r1[r2]	//r1 is now the windowing coefficient
			ldaw r0, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			ldd r2, r3, r0[S_D_SECOND_STAGE_OUTPUT_01]
			{ldc r4, 0; ldc r5, 0}
			maccs r4, r5, r1, r2
			{ldc r2, 0; ldc r5, 0}
			maccs r5, r3, r1, r3
			std r4, r5, r0[S_D_SECOND_STAGE_OUTPUT_01]
			ldd r2, r3, r0[S_D_SECOND_STAGE_OUTPUT_23]
			{ldc r4, 0; ldc r5, 0}
			maccs r4, r5, r1, r2
			{ldc r2, 0; ldc r5, 0}
			maccs r5, r3, r1, r3
			std r2, r3, r0[S_D_SECOND_STAGE_OUTPUT_23]
		no_windowing:

		ldaw r0, sp[S_FRAME_OFFSET]
		ldw r2, r0[S_FRAME_SIZE_LOG2]
		ldaw r1, sp[S_SETTINGS_OFFSET]
		ldw r1, r1[S_INDEX_BITREVERSING_ENABLED]
		bf r1, write_out_audio_frames
		write_out_fft_frames:
			ldaw r5, sp[S_SECOND_STAGE_OUTPUT_OFFSET]
			{ldw r1, r0[S_AUDIO_POINTER_0_INDEX]; ldc r3, 32}
			{bitrev r1, r1; sub r3, r3, r2}
			{shr r1, r1, r3;ldw r4, r0[S_AUDIO_POINTER_0]}
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
			ldd r3, r4, r0[S_D_AUDIO_POINTER_AND_INDEX_0]
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
			ldw r1, r0[S_AUDIO_POINTER_0_INDEX]
			{add r1, r1, 1;}
			zext r1, r2
			stw r1, r0[S_AUDIO_POINTER_0_INDEX];
			bt r1, input_sample_7
	exchange_buffers:
		ldw r1, r0[S_C_OUTPUT]
		outct res[r1], 8 //WARNING: do not change this

		inct r2, res[r1]
		//if the incomming token is EXCHANGE_BUFFERS then do that
		//if the incomming token is CONFIGURE_DECIMATOR then do that

		eq r3, r2, CONFIGURE_DECIMATOR
		bt r3, configure
		eq r3, r2, EXCHANGE_BUFFERS
		bt r3, do_the_exchange

		do_the_exchange:

		save_the_metadata:
		{ldd r3, r4, r0[S_D_FRAME_MIN_MAX_0]}
		ldw r5, r0[S_METADATA_POINTER_0]
		std r3, r4, r5[0];
		ldw r3, r0[S_FRAME_NUMBER]
		{stw r3, r5[2]; add r3, r3, 1}
		stw r3, r0[S_FRAME_NUMBER]		//and save the new frame number back

		get_the_new_data_pointer:
		in r2, res[r1]
		{stw r2, r0[S_AUDIO_POINTER_0]}
		get_the_new_metadata_pointer:
	    in r1, res[r1]
		{ldc r1, 0; stw r1, r0[S_METADATA_POINTER_0]}
		//reset the min and max vals for the frame
		{stw r1, r0[S_FRAME_MAX_0]}
		{stw r1, r0[S_FRAME_MIN_0]}

input_sample_7:
	INPUT(S_D_INPUT_7)	//162 instruction per loop
		integrate_0:
		INTEGRATE(0, 0,  1,  2)	//71 inst
		integrate_1:
		INTEGRATE(1, 3,  4,  5) //71 inst
	bl ds_loop

.tmp_decimate_to_pcm_4ch:
	.size	decimate_to_pcm_4ch, .tmp_decimate_to_pcm_4ch-decimate_to_pcm_4ch
	.align	4
	.cc_bottom decimate_to_pcm_4ch.function

	.set	decimate_to_pcm_4ch.nstackwords,NSTACKWORDS
	.globl	decimate_to_pcm_4ch.nstackwords
	.set	decimate_to_pcm_4ch.maxcores,1
	.globl	decimate_to_pcm_4ch.maxcores
	.set	decimate_to_pcm_4ch.maxtimers,0
	.globl	decimate_to_pcm_4ch.maxtimers
	.set	decimate_to_pcm_4ch.maxchanends,0
	.globl	decimate_to_pcm_4ch.maxchanends


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
	//ldc t, 24*4
	//{add r7, r7, t; add r6, r6, t}
	//DOUBLE_TAP(0)
	//DOUBLE_TAP(2)
	//TODO add the most possible - try to get to 60
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

//endpoint section
#define STRINGIZE(S) #S

#define EP_MARCO(ID) \
	.ascii	STRINGIZE( input_sample_ ## ID ## _ep ) ;\
	.byte	0 ;\
	.ascii	"../src/test_lib_include.xc" ;\
	.byte	0 ;\
	.long	124 ;\
	.long	.Laddr_end ## ID -.Laddr_start ## ID ;\
	.Laddr_start ## ID : ;\
	.cc_top cc_ ## ID,input_sample_ ## ID;\
	.long	input_sample_ ## ID ;\
	.byte	0 ;\
	.cc_bottom cc_ ## ID ;\
	.Laddr_end ## ID :

#define EPT_MARCO(ID) \
.cc_top cc_a ## ID,input_sample_ ## ID ;\
	.ascii	"";\
	.byte	0;\
	.long	0;\
	.long	input_sample_ ## ID ;\
.cc_bottom cc_a ## ID

	.section	.xtaendpoint,"",@progbits
.Lentries_start0:
	.long	.Lentries_end0-.Lentries_start0
	.long	1
	.ascii	"/home/andrew/lib_mic_array/tests/test_lib_include/.build"
    .byte	0
	EP_MARCO(0)
	EP_MARCO(1)
	EP_MARCO(2)
	EP_MARCO(3)
	EP_MARCO(4)
	EP_MARCO(5)
	EP_MARCO(6)
	EP_MARCO(7)
	.ascii	"configure_ep"
	.byte	0
	.ascii	"../src/test_lib_include.xc"
	.byte	0
	.long	123
	.long	.Laddr_end8-.Laddr_start8
.Laddr_start8:
.cc_top cc_8,configure
	.long	configure
	.byte	0
.cc_bottom cc_8
.Laddr_end8:

.Lentries_end0:
	.section	.xtaendpointtable,"",@progbits
.Lentries_start1:
	.long	.Lentries_end1-.Lentries_start1
	.long	0
	.ascii	""
	.byte	0
	EPT_MARCO(0)
	EPT_MARCO(1)
	EPT_MARCO(2)
	EPT_MARCO(3)
	EPT_MARCO(4)
	EPT_MARCO(5)
	EPT_MARCO(6)
	EPT_MARCO(7)
.cc_top cc_18,configure
	.ascii	""
	.byte	0
	.long	10
	.long	configure
.cc_bottom cc_18
.Lentries_end1:

