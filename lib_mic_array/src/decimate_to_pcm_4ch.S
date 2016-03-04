// Copyright (c) 2016, XMOS Ltd, All rights reserved
	.section	.dp.data,"awd",@progbits
	.text

#include "mic_array_conf.h"

#define USE_SINGLE_CHAN_SAVING 0

#ifndef MIC_ARRAY_MAX_FRAME_SIZE_LOG2
	#error MIC_ARRAY_MAX_FRAME_SIZE_LOG2 is not defined in mic_array_conf.h
#endif

#ifndef MIC_ARRAY_DC_OFFSET_LOG2
	#define MIC_ARRAY_DC_OFFSET_LOG2 8
#endif

.xtacommand "analyse endpoints input_0_0_ep input_1_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_1_0_ep input_2_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_2_0_ep input_3_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_3_0_ep input_4_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_4_0_ep input_5_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_5_0_ep input_6_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_6_0_ep input_7_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_7_0_ep input_0_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_0_1_ep input_1_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_1_1_ep input_2_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_2_1_ep input_3_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_3_1_ep input_4_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_4_1_ep input_5_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_5_1_ep input_6_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_6_1_ep input_7_1_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__
.xtacommand "analyse endpoints input_7_1_ep input_0_0_ep","", __FILE__, __LINE__
.xtacommand "set required - 2604 ns","", __FILE__, __LINE__

#define SECOND_STAGE_COEF_COUNT 		16		//This must reflect the implementation in mic_array_decimate_to_pcm_4ch_fir_impl
#define THIRD_STAGE_COEFS_PER_STAGE 	32		//This must reflect the implementation in third_stage_fir_impl
#define THIRD_STAGE_COEFS_PER_ROW 		63		//This must reflect the implementation in third_stage_fir_impl
#define MAX_DECIMATION_FACTOR      		12

//derived defines
#define SECOND_STAGE_BUFFER_SIZE		(SECOND_STAGE_COEF_COUNT*2)

//////////////////////////////////////////////////////////////////////////////////////

//This stuff is at the start of the stack for really quick access
#define S_STORAGE 				0

#define S_UNUSED				0
#define S_C_INPUT 				1

#define S_C_OUTPUT 				2
#define S_CHAN_COUNT 	 		3

#define S_D_DC_OFFSET_LOG2_CH01 2
#define S_D_DC_OFFSET_LOG2_CH23 3

#define S_DC_OFFSET_LOG2_CH0   	4
#define S_DC_OFFSET_LOG2_CH1   	5
#define S_DC_OFFSET_LOG2_CH2   	6
#define S_DC_OFFSET_LOG2_CH3   	7

#define S_DC_OFFSET_SAMPLE_NO   8

#define S_FIR_GAIN_COMP     	9
#define S_SIG_BITS_MASK     	10
#define S_NOT_YET_USED     		11
#define S_STORAGE_SIZE 			12

//////////////////////////////////////////////////////////////////////////////////////
//this address must be double word aligned
#define S_SECOND_STAGE_DATA 		(S_STORAGE + S_STORAGE_SIZE)
#define S_SECOND_STAGE_DATA_SIZE 	(16*2*4)		//16 words by 2 blocks by 4 channels

//////////////////////////////////////////////////////////////////////////////////////

#define S_THIRD_STAGE 					(S_SECOND_STAGE_DATA + S_SECOND_STAGE_DATA_SIZE)

#define S_D_THIRD_STAGE_PHASE_AND_COUNT 0	//0 1
											//2 3
#define S_D_THIRD_STAGE_POINTERS        1	//4 5
#define S_D_THIRD_STAGE_CH0_ACC 		3	//6 7
#define S_D_THIRD_STAGE_CH1_ACC 		4	//8 9
#define S_D_THIRD_STAGE_CH2_ACC 		5	//10 11
#define S_D_THIRD_STAGE_CH3_ACC 		6	//12 13

#define S_THIRD_STAGE_PHASE 			0		//need to be 0-11 for divide_by_four
#define S_THIRD_STAGE_PHASE_COUNT 		1
#define S_THIRD_STAGE_DATA_POINTER      2
#define S_THIRD_STAGE_COEFS_POINER		3
#define S_THIRD_STAGE_COEFS_PHASE		4
#define S_THIRD_STAGE_UNUSED			5
#define S_THIRD_STAGE_SIZE				(16)

//////////////////////////////////////////////////////////////////////////////////////

#define S_OUTPUT_STORAGE (S_THIRD_STAGE+S_THIRD_STAGE_SIZE)
#define S_D_OUTPUT_STORAGE_01 0
#define S_D_OUTPUT_STORAGE_23 1
#define S_OUTPUT_STORAGE_SIZE 4

//////////////////////////////////////////////////////////////////////////////////////

//Note: this will survive a reconfig
#define S_DC_ELIMINATE 					(S_OUTPUT_STORAGE+S_OUTPUT_STORAGE_SIZE)
#define S_PREV_X_0						0
#define S_PREV_X_1						1
#define S_PREV_X_2						2
#define S_PREV_X_3						3

#define S_D_PREV_X_01					0
#define S_D_PREV_X_23					1
#define S_D_PREV_Y_0 					2
#define S_D_PREV_Y_1 					3
#define S_D_PREV_Y_2 					4
#define S_D_PREV_Y_3 					5
#define DC_ELIMINATE_STACK_SIZE 		12

//frame
#define S_FRAME_OFFSET (S_DC_ELIMINATE + DC_ELIMINATE_STACK_SIZE)
#define S_D_FRAME_POINTER_AND_INDEX_0 3
#define S_D_FRAME_POINTER_AND_INDEX_1 4
#define S_D_FRAME_MIN_MAX_0       	  5
#define S_D_FRAME_MIN_MAX_1       	  6
#define S_C_UNUSED				0
#define S_FRAME_SIZE_LOG2		1	//this is the current frame size log2
#define S_FRAME_NUMBER			2	//should this be presistant between configs?
#define S_OVERLAPPING_FRAMES    3	//0 for on overlap, 1 for overlapping
#define S_METADATA_POINTER_0    4
#define S_METADATA_POINTER_1    5
#define S_FRAME_POINTER_0 		6	//pointer to the current frame
#define S_FRAME_0_INDEX     	7	//index to write to the current frame
#define S_FRAME_POINTER_1 		8	//pointer to the next frame
#define S_FRAME_1_INDEX     	9	//index to write to the next frame
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
#define S_WINDOWING_ENABLED 			0	//0 for disabled, pointer for enabled
#define S_INDEX_BITREVERSING_ENABLED 	1
#define S_DC_OFFSET_REMOVAL_ENABLED 	2
#define S_DECIMATION_FACTOR_is_now_S_THIRD_STAGE_PHASE_COUNT 			3
#define S_MIC_GAIN_COMP		 			4
#define S_SETTINGS_SIZE					6

//This must be an even number
#define STACKWORDS 						(S_SETTINGS_OFFSET + S_SETTINGS_SIZE)

//This is used for commenting within marcos
#define comment(X)

//TODO - use this when everything works
//TODO then reduce the memory usage
//Note: there could be two implementations of this where one never writes to
//memory 28-32 as they are never used
#define INPUT_TO_OFFSET_12_15(OFFSET) \
	ldw r1, sp[S_C_INPUT]; \
	in r0, res[r1];\
	{stw r0, dp[0*SECOND_STAGE_BUFFER_SIZE + OFFSET]; in r0, res[r1]};\
	{stw r0, dp[1*SECOND_STAGE_BUFFER_SIZE + OFFSET]; in r0, res[r1]};\
	stw r0, dp[2*SECOND_STAGE_BUFFER_SIZE + OFFSET];\
	in r0, res[r1];\
	{stw r0, dp[3*SECOND_STAGE_BUFFER_SIZE + OFFSET]}

//This inputs from the channel to the pdm interface and saves it twice in the
//second stage FIR at offset OFFSET and OFFSET + 16
#define INPUT_TO_OFFSET(OFFSET) \
	ldw r1, sp[S_C_INPUT]; \
	in r0, res[r1];\
	{stw r0, dp[0*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
	{stw r0, dp[0*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_COEF_COUNT + OFFSET]; in r0, res[r1]};\
	{stw r0, dp[1*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
	{stw r0, dp[1*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_COEF_COUNT + OFFSET]; in r0, res[r1]};\
	{stw r0, dp[2*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
	{stw r0, dp[2*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_COEF_COUNT + OFFSET]};\
	in r0, res[r1];\
	{stw r0, dp[3*SECOND_STAGE_BUFFER_SIZE + OFFSET]};\
	{stw r0, dp[3*SECOND_STAGE_BUFFER_SIZE + SECOND_STAGE_COEF_COUNT + OFFSET]}


//setup divider by N registers (coefs, data, accumulators)
//must avoid r0 and r1 for persistant state as they will be clobbered by INPUT_TO_OFFSET
	//coef = coef[THIRD_STAGE_COEFS_PER_STAGE-1] ---this is done offline
	//coef = coef[THIRD_STAGE_COEFS_PER_ROW*S_THIRD_STAGE_PHASE - S_THIRD_STAGE_COEFS_PHASE]
	//data0 = data[THIRD_STAGE_COEFS_PER_STAGE*S_THIRD_STAGE_PHASE*4]
	//data1 = data0[THIRD_STAGE_COEFS_PER_STAGE]
#define DIVIDE_BY_N_0()\
	ldaw r0, sp[S_THIRD_STAGE];\
	{ldw r7, r0[S_THIRD_STAGE_PHASE]; ldc r6, THIRD_STAGE_COEFS_PER_ROW};\
	mul r6, r6, r7;\
	{ldw r5, r0[S_THIRD_STAGE_COEFS_PHASE]; ldc r8, THIRD_STAGE_COEFS_PER_STAGE};\
	{sub r6, r6, r5; ldw r9, r0[S_THIRD_STAGE_COEFS_POINER]};\
	ldaw r9, r9[r6];\
	mul r7, r7, r8;\
	ldw r6, sp[S_CHAN_COUNT];\
	mul r7, r7, r6;\
	ldw r10, r0[S_THIRD_STAGE_DATA_POINTER];\
	ldaw r10, r10[r7];\
	ldaw r11, r10[r8];\
	ldd r8, r7, r0[S_D_THIRD_STAGE_CH0_ACC];\
	ldd r6, r5, r0[S_D_THIRD_STAGE_CH1_ACC];\
	bl third_stage_fir_impl;\
	ldaw r0, sp[S_THIRD_STAGE];\
	std r8, r7, r0[S_D_THIRD_STAGE_CH0_ACC];\
	std r6, r5, r0[S_D_THIRD_STAGE_CH1_ACC]

#define N_DIVIDE_BY_N_1()\
	{ldc r0, THIRD_STAGE_COEFS_PER_STAGE};\
	ldaw r9, r9[-r0];\
	ldc r0, THIRD_STAGE_COEFS_PER_STAGE-24;\
	ldaw r10, r11[r0];\
	{ldc r0, THIRD_STAGE_COEFS_PER_STAGE};\
	ldaw r11, r10[r0];\
	ldaw r0, sp[S_THIRD_STAGE];\
	ldd r8, r7, r0[S_D_THIRD_STAGE_CH2_ACC];\
	ldd r6, r5, r0[S_D_THIRD_STAGE_CH3_ACC];\
	bl third_stage_fir_impl;\
	ldaw r0, sp[S_THIRD_STAGE];\
	std r8, r7, r0[S_D_THIRD_STAGE_CH2_ACC];\
	std r6, r5, r0[S_D_THIRD_STAGE_CH3_ACC]

#define DC_OFFSET_REMOVAL(PREV_Y, PREV_X, REGISTER) \
	ldd r6, r5, r4[PREV_Y];\
	ldc r7, MIC_ARRAY_DC_OFFSET_LOG2;\
	ashr r9, r6, r7;\
	lextract r8, r6, r5, r7, 32;\
	lsub r11, r5, r5, r8, r4; 		comment(using the lowest bit of r4 which is always 0) \
    lsub r11, r6, r6, r9, r11; \
    {ldw r7, r4[PREV_X]};\
    ashr r9, REGISTER, 32;\
    ashr r10, r7, 32;\
    lsub r11, r8, REGISTER, r7, r4; 	comment(same here) \
    lsub r11, r9, r9, r10, r11;\
    {ldc r10, 16};\
    lextract r9, r9, r8, r10, 32;\
    {shl r8, r8, r10; stw REGISTER, r4[PREV_X]};\
    lsub r11, r5, r5, r8, r4; 		comment(same here) \
    lsub r11, r6, r6, r9, r11;\
	std r6, r5, r4[PREV_Y];\
	lextract REGISTER, r6, r5, r10, 32

//r6 is the AUDIO_POINTER_INDEX		--note that on the second pass r0-r3 will need to be reloaded as this modified them
#define APPLY_WINDOW_FN(P)\
	ldaw r9, sp[S_SETTINGS_OFFSET];\
	ldw r9, r9[S_WINDOWING_ENABLED];\
	bf r9, done_windowing ## P;\
	apply_windowing ## P:;\
		ldw r5, r4[S_FRAME_SIZE_LOG2];\
		{shl r5, r6, 1; mkmsk r8, r5};\
		{lss r5, r8, r5; ldc r7, 31};\
		{bf r5, skip ## P ; mov r4, r6};\
			sub r4, r8, r6;\
		skip ## P:;\
		{ldc r10, 0; ldc r11, 0};\
		{ldw r4, r9[r4]};\
		maccs r10, r11, r4, r0;\
		lextract r0, r10, r11, r7, 32;\
		{ldc r10, 0; ldc r11, 0};\
		maccs r10, r11, r4, r1;\
		lextract r1, r10, r11, r7, 32;\
		{ldc r10, 0; ldc r11, 0};\
		maccs r10, r11, r4, r2;\
		lextract r2, r10, r11, r7, 32;\
		{ldc r10, 0; ldc r11, 0};\
		maccs r10, r11, r4, r3;\
		lextract r3, r10, r11, r7, 32;\
	done_windowing ## P:

//r4 is the address of the S_FRAME_OFFSET_SECTION
//r6 is the AUDIO_POINTER_INDEX
#if MIC_ARRAY_WORD_LENGTH_SHORT
	#define SAVE_SAMPLES_BIT_REVERSED(POINTER)\
		{ldw r5, r4[S_FRAME_SIZE_LOG2]; ldc r7, 32};\
		{bitrev r6, r6; ldc r8, 2};\
		{sub r9, r7, r5;ldw r11, sp[S_CHAN_COUNT]};\
		{lsu r11, r8, r11 ;ldc r8, (MIC_ARRAY_MAX_FRAME_SIZE_LOG2+2)};\
		{shl r8, r11, r8;ldw r7, r4[POINTER]  };\
		{add r8, r7, r8;shr r6, r6, r9;};\
		{shr r0, r0, 16; shr r1, r1, 16};\
		{shr r2, r2, 16; shr r3, r3, 16};\
		{shl r1, r1, 16; shl r3, r3, 16};\
		{add r1, r1, r0; add r3, r3, r2};\
		stw r3, r8[r6];\
		stw r1, r7[r6]

#else
	#define SAVE_SAMPLES_BIT_REVERSED(POINTER)\
			{ldw r5, r4[S_FRAME_SIZE_LOG2]; ldc r7, 32};\
			{bitrev r6, r6; ldc r8, 2};\
			{sub r9, r7, r5;ldw r11, sp[S_CHAN_COUNT]};\
			{lsu r11, r8, r11 ;ldc r8, (MIC_ARRAY_MAX_FRAME_SIZE_LOG2+3)};\
			{shl r8, r11, r8;ldw r7, r4[POINTER]  };\
			{add r8, r7, r8;shr r6, r6, r9;};\
			std r3, r2, r8[r6];\
			std r1, r0, r7[r6]

#endif

//r4 is the address of the S_FRAME_OFFSET_SECTION
//r6 is the AUDIO_POINTER_INDEX
#if MIC_ARRAY_WORD_LENGTH_SHORT
	#define SAVE_SAMPLES_NORMAL(POINTER, N)\
		{ldc r5, 1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2)};\
    	{add r7, r6, r5; ldw r8, r4[POINTER]};\
    	{ldw r11, sp[S_CHAN_COUNT]; add r5, r5, r5};\
		{eq r10, r11, 4;  nop };\
		{shr r0, r0, 16; shr r1, r1, 16};\
		{shr r2, r2, 16; shr r3, r3, 16};\
		{bf r10, not_four ## N; eq r10, r11, 3};\
		st16 r1, r8[r7];\
		st16 r0, r8[r6];\
		{add r7, r7, r5; add r6, r6, r5};\
		st16 r3, r8[r7];\
		st16 r2, r8[r6];\
		bu done ## N;\
		not_four ## N:;\
		{bf r10, not_three ## N; eq r10, r11, 2};\
		st16 r1, r8[r7];\
		st16 r0, r8[r6];\
		{nop; add r6, r6, r5};\
		st16 r2, r8[r6];\
		bu done ## N;\
		not_three ## N:;\
		{bf r10, not_two ## N; eq r10, r11, 1};\
		st16 r1, r8[r7];\
		st16 r0, r8[r6];\
		bu done ## N;\
		not_two ## N:;\
		{bf r10, done ## N; eq r10, r11, 0};\
		st16 r0, r8[r6];\
		done ## N:

#else
	#define SAVE_SAMPLES_NORMAL(POINTER, N)\
		{ldc r5, 1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2)};\
    	{add r7, r6, r5; ldw r8, r4[POINTER]};\
    	{ldw r11, sp[S_CHAN_COUNT]; add r5, r5, r5};\
		{eq r10, r11, 4;  nop };\
		{bf r10, not_four ## N; eq r10, r11, 3};\
		stw r1, r8[r7];\
		stw r0, r8[r6];\
		{add r7, r7, r5; add r6, r6, r5};\
		stw r3, r8[r7];\
		stw r2, r8[r6];\
		bu done ## N;\
		not_four ## N:;\
		{bf r10, not_three ## N; eq r10, r11, 2};\
		stw r1, r8[r7];\
		stw r0, r8[r6];\
		{nop; add r6, r6, r5};\
		stw r2, r8[r6];\
		bu done ## N;\
		not_three ## N:;\
		{bf r10, not_two ## N; eq r10, r11, 1};\
		stw r1, r8[r7];\
		stw r0, r8[r6];\
		bu done ## N;\
		not_two ## N:;\
		{bf r10, done ## N; eq r10, r11, 0};\
		stw r0, r8[r6];\
		done ## N:

#endif

.globl	mic_array_decimate_to_pcm_4ch
.align	8
.type	mic_array_decimate_to_pcm_4ch,@function
.cc_top mic_array_decimate_to_pcm_4ch.function
mic_array_decimate_to_pcm_4ch:
.cfi_startproc
.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

	ldaw r2, sp[S_STORAGE]
	stw r0, r2[S_C_INPUT]
	stw r1, r2[S_C_OUTPUT]

	//Set the dp to point to the data area for the second stage FIR
	ldaw dp, sp[S_SECOND_STAGE_DATA]

	outct res[r1], 8		//we say we are ready
	inct r2, res[r1]		//they say CONFIGURE_DECIMATOR

	// Initialise the DC offset removal.
	ldaw r0, sp[S_DC_ELIMINATE];
	ldc r1, 0
	std r1, r1, r0[S_D_PREV_X_01]
	std r1, r1, r0[S_D_PREV_X_23]
	std r1, r1, r0[S_D_PREV_Y_0]
	std r1, r1, r0[S_D_PREV_Y_1]
	std r1, r1, r0[S_D_PREV_Y_2]
	std r1, r1, r0[S_D_PREV_Y_3]
	ldw r1, sp[S_DC_OFFSET_SAMPLE_NO]
	ldc r1, 8 // This cotrols the rate of convergence of the DC offset
			  // for the initial sample. It has little effect, i.e. don't change it.
	ldw r1, sp[S_DC_OFFSET_LOG2_CH0]
	ldw r1, sp[S_DC_OFFSET_LOG2_CH1]
	ldw r1, sp[S_DC_OFFSET_LOG2_CH2]
	ldw r1, sp[S_DC_OFFSET_LOG2_CH3]

configure:
	DUALENTSP_lu6 0
	//Initialise the stack -- TODO optimise this
	ldc r0, (S_DC_ELIMINATE - S_SECOND_STAGE_DATA)/2
	{ldaw r1, sp[S_SECOND_STAGE_DATA];ldc r2, 0}
stack_init_loop:
	std r2, r2, r1[r0]
	{bt r0, stack_init_loop; sub r0, r0, 1}

take_config_from_application:
	//get the pointer for the config over the output channel
	ldw r0, sp[S_C_OUTPUT]
	in r2, res[r0]		//deciamtor_config
	ldw r3, r2[0];		//r3 is the pointer to the decimator_config_common

//copy the setting out of the struct
	ldaw r0, sp[S_FRAME_OFFSET]
	ldw r11, r3[0] //frame_size_log2
	here_is_frame_size_log2:
	stw r11, r0[S_FRAME_SIZE_LOG2]

	ldaw r0, sp[S_SETTINGS_OFFSET]

	ldw r11, r3[1] //apply_dc_offset
	stw r11, r0[S_DC_OFFSET_REMOVAL_ENABLED]

	ldw r11, r3[2] //index_bit_reversal
	stw r11, r0[S_INDEX_BITREVERSING_ENABLED]

	ldw r11, r3[3] //windowing_function
	stw r11, r0[S_WINDOWING_ENABLED]

	ldw r11, r3[6]	//apply mic gain compensation
	stw r11, r0[S_MIC_GAIN_COMP]

	ldw r11, r3[7]	//fir_gain_comp
	stw r11, sp[S_FIR_GAIN_COMP]

	ldw r11, r3[4] 	//decimation factor
	ldaw r10, sp[S_THIRD_STAGE]
	stw r11, r10[S_THIRD_STAGE_PHASE_COUNT]

	here_is_the_coef_pointer:
	{ldw r11, r3[5];} //coef pointer
	ldc r9, (THIRD_STAGE_COEFS_PER_STAGE-1)			//move the coef pointer along by (THIRD_STAGE_COEFS_PER_STAGE-1)
	ldaw r11, r11[r9]
	stw r11, r10[S_THIRD_STAGE_COEFS_POINER]

	here_is_the_data_pointer:
	{ldw r11, r2[1];} //data pointer
	stw r11, r10[S_THIRD_STAGE_DATA_POINTER]

	{ldw r11, r2[6];} //channel count
	stw r11, sp[S_CHAN_COUNT]

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

init_frame_index:
	ldaw r11, sp[S_FRAME_OFFSET]
	ldc r1, 0
	stw r1, r11[S_FRAME_0_INDEX]

	ldw r1, r11[S_FRAME_SIZE_LOG2]
	{sub r1, r1, 1; ldc r10, 1}
	shl r1, r10, r1
	stw r1, r11[S_FRAME_1_INDEX]
	std r1, r1, r11[S_D_FRAME_MIN_MAX_0]
	std r1, r1, r11[S_D_FRAME_MIN_MAX_1]

get_frame_pointer:
	ldw r2, sp[S_C_OUTPUT]
	rx_buffer_count:
	in r5, res[r2]
	sub r5, r5, 1

	bt r5, overlapping
	non_overlapping:
	    {in r1, res[r2];stw r5, r11[S_OVERLAPPING_FRAMES]}
	    {in r1, res[r2];stw r1, r11[S_FRAME_POINTER_0]}
	    saving_non_overlapping_metadata_pointer:
		stw r1, r11[S_METADATA_POINTER_0]
		bu setup_phase_counters

	overlapping:
	    {in r1, res[r2];}
	    {in r1, res[r2];stw r1, r11[S_FRAME_POINTER_1]}
	    saving_overlapping_metadata_pointer_1:
		stw r1, r11[S_METADATA_POINTER_1]
	    {in r1, res[r2];stw r5, r11[S_OVERLAPPING_FRAMES]}
	    {in r1, res[r2];stw r1, r11[S_FRAME_POINTER_0]}
	    saving_overlapping_metadata_pointer_0:
		stw r1, r11[S_METADATA_POINTER_0]

setup_phase_counters:
	ldaw r10, sp[S_THIRD_STAGE]
	ldw r9, r10[S_THIRD_STAGE_PHASE_COUNT]
	sub r9, r9, 1
	stw r9, r10[S_THIRD_STAGE_PHASE]

	ldc r9, (THIRD_STAGE_COEFS_PER_STAGE-1)
	stw r9, r10[S_THIRD_STAGE_COEFS_PHASE]

confirm_init_complete:
	ldw r4, sp[S_C_OUTPUT]
	outct res[r4], 8 //WARNING: do not change this

input_0_0:
	INPUT_TO_OFFSET_12_15(15)
	divide_by_n_0_0:
	DIVIDE_BY_N_0()

input_1_0:
	INPUT_TO_OFFSET_12_15(14)
	divide_by_n_0_1:
	N_DIVIDE_BY_N_1()

input_2_0:
	INPUT_TO_OFFSET_12_15(13)
	bl post_process

input_3_0:
	INPUT_TO_OFFSET_12_15(12)
	ldaw r7, dp[12]
	bl divide_by_four

input_4_0:
	INPUT_TO_OFFSET(11)
	divide_by_n_1_0:
	DIVIDE_BY_N_0();

input_5_0:
	INPUT_TO_OFFSET(10)
	divide_by_n_1_1:
	N_DIVIDE_BY_N_1()

input_6_0:
	INPUT_TO_OFFSET(9)
	bl post_process

input_7_0:
	INPUT_TO_OFFSET(8)
	ldaw r7, dp[8]
	bl divide_by_four

input_0_1:
	INPUT_TO_OFFSET(7)
	divide_by_n_2_0:
	DIVIDE_BY_N_0();

input_1_1:
	INPUT_TO_OFFSET(6)
	divide_by_n_2_1:
	N_DIVIDE_BY_N_1()

input_2_1:
	INPUT_TO_OFFSET(5)
	bl post_process

input_3_1:
	INPUT_TO_OFFSET(4)
	ldaw r7, dp[4]
	bl divide_by_four

input_4_1:
	INPUT_TO_OFFSET(3)
	divide_by_n_3_0:
	DIVIDE_BY_N_0();

input_5_1:
	INPUT_TO_OFFSET(2)
	divide_by_n_3_1:
	N_DIVIDE_BY_N_1()

input_6_1:
	INPUT_TO_OFFSET(1)
	bl post_process

input_7_1:
	INPUT_TO_OFFSET(0)
	ldaw r7, dp[0]
	bl divide_by_four
	bu input_0_0

	.cc_bottom mic_array_decimate_to_pcm_4ch.function
	.set	mic_array_decimate_to_pcm_4ch.nstackwords, STACKWORDS
	.globl	mic_array_decimate_to_pcm_4ch.nstackwords
	.set	mic_array_decimate_to_pcm_4ch.maxcores,1
	.globl	mic_array_decimate_to_pcm_4ch.maxcores
	.set	mic_array_decimate_to_pcm_4ch.maxtimers,0
	.globl	mic_array_decimate_to_pcm_4ch.maxtimers
	.set	mic_array_decimate_to_pcm_4ch.maxchanends,0
	.globl	mic_array_decimate_to_pcm_4ch.maxchanends
.Lmic_array_decimate_to_pcm_4ch_tmp:
	.size	mic_array_decimate_to_pcm_4ch, .Lmic_array_decimate_to_pcm_4ch_tmp-mic_array_decimate_to_pcm_4ch
	.cfi_endproc

//////////////////////////////////////////////////////////////////////////////////////////

.globl	post_process
.align	8
.type	post_process,@function
.cc_top post_process.function
post_process:
	.cfi_startproc
	.issue_mode dual

	//increment THIRD_STAGE_PHASE mod THIRD_STAGE_PHASE_COUNT
	ldaw r11, sp[S_THIRD_STAGE]
	ldw r10, r11[S_THIRD_STAGE_PHASE];
	{add r9, r10, 1; ldw r8, r11[S_THIRD_STAGE_PHASE_COUNT]}
	{stw r9, r11[S_THIRD_STAGE_PHASE];eq r8, r8, r9}

	bt r8, output_phase
	bf r10, process_phase
	retsp 0

	process_phase:
	//r0, r1, r2, r3 are used as storage for the output of the 3rd stage FIR
	//copy the accumulators in to registers
	ldaw r4, sp[S_OUTPUT_STORAGE];
	ldd r0, r1, r4[S_D_OUTPUT_STORAGE_01];
	ldd r2, r3, r4[S_D_OUTPUT_STORAGE_23];

	//DC offset removal
	ldaw r4, sp[S_SETTINGS_OFFSET]
	ldw r4, r4[S_DC_OFFSET_REMOVAL_ENABLED]
	bf r4, dc_offset_removal_complete

		ldaw r4, sp[S_DC_ELIMINATE]
		dc_offset_removal_ch0:
		DC_OFFSET_REMOVAL(S_D_PREV_Y_0, S_PREV_X_0, r0);
		dc_offset_removal_ch1:
		DC_OFFSET_REMOVAL(S_D_PREV_Y_1, S_PREV_X_1, r1);
		dc_offset_removal_ch2:
		DC_OFFSET_REMOVAL(S_D_PREV_Y_2, S_PREV_X_2, r2);
		dc_offset_removal_ch3:
		DC_OFFSET_REMOVAL(S_D_PREV_Y_3, S_PREV_X_3, r3);

dc_offset_removal_complete:

#define COMP(REG)\
	{ldc r5, 0; ldc r6, 0};\
	maccs r5, r6, REG, r4;\
	lsats r5, r6, r7;\
	lextract REG, r5, r6, r7, 32

	//FIR gain compensation
	fir_compensation:	// This normally turns the volume up to compensate for the FIR
	ldw r4, sp[S_FIR_GAIN_COMP]  //load the fir gain comp, it is in 1.4.27 format
	{bf r4, gain_compensation;ldc r7, 27}
	COMP(r0)
	COMP(r1)
	COMP(r2)
	COMP(r3)

	gain_compensation:	// This always turns the volume down
	ldaw r4, sp[S_SETTINGS_OFFSET]
	ldw r4, r4[S_MIC_GAIN_COMP]
	{bf r4, gain_comp_complete;ldc r7, 31}
	apply_mic_gain_compensation:
		ldaw r4, sp[S_MIC_CALIB_OFFSET]
		ldd r6, r5, r4[S_D_MIC_CALIB_01]
		{ldc r8, 0; ldc r9, 0}
		maccs r8, r9, r0, r5
		lextract r0, r8, r9, r7, 32
		{ldc r8, 0; ldc r9, 0}
		maccs r8, r9, r1, r6
		lextract r1, r8, r9, r7, 32
		ldd r6, r5, r4[S_D_MIC_CALIB_23]
		{ldc r8, 0; ldc r9, 0}
		maccs r8, r9, r2, r5
		lextract r2, r8, r9, r7, 32
		{ldc r8, 0; ldc r9, 0}
		maccs r8, r9, r3, r6
		lextract r3, r8, r9, r7, 32
	gain_comp_complete:

	zero_unused_channels:
	{ldw r4, sp[S_CHAN_COUNT];}
	eq r5, r4, 4
	bt r5, zero_channels_complete
	{ldc r3, 0; eq r5, r4, 3}
	bt r5, zero_channels_complete
	{ldc r2, 0; eq r5, r4, 2}
	bt r5, zero_channels_complete
	{ldc r1, 0; eq r5, r4, 1}
	bt r5, zero_channels_complete
	ldc r0, 0
	zero_channels_complete:


	{clz r4, r0;		ldw	r11, sp[S_SIG_BITS_MASK]}
	{neg r5, r0;		clz r6, r1 }
	{clz r5, r5;		neg r7, r1 }
	{add r4, r5, r4;	clz r7, r7 }
	{mkmsk r4, r4;      add r6, r6, r7}
	{and r11, r11, r4;   mkmsk r6, r6}
	{clz r4, r1;		and r11, r11, r6}
	{neg r5, r1;		clz r6, r2 }
	{clz r5, r5;		neg r7, r2 }
	{add r4, r5, r4;	clz r7, r7 }
	{mkmsk r4, r4;      add r6, r6, r7}
	{and r11, r11, r4;   mkmsk r6, r6}
	{	nop			;	and r11, r11, r6}
	{stw r11, sp[S_SIG_BITS_MASK] }

	ldaw r4, sp[S_OUTPUT_STORAGE];
	std r0, r1, r4[S_D_OUTPUT_STORAGE_01];
	std r2, r3, r4[S_D_OUTPUT_STORAGE_23];
	retsp 0

	output_phase:

#define EXCHANGE_BUFFERS 0
#define CONFIGURE_DECIMATOR 1

		ldaw r4, sp[S_OUTPUT_STORAGE];
		ldd r0, r1, r4[S_D_OUTPUT_STORAGE_01];
		ldd r2, r3, r4[S_D_OUTPUT_STORAGE_23];

		ldaw r4, sp[S_FRAME_OFFSET]

		ldw r6, r4[S_FRAME_0_INDEX]

		APPLY_WINDOW_FN(0)
		ldaw r4, sp[S_FRAME_OFFSET]

		ldaw r5, sp[S_SETTINGS_OFFSET]
		ldw r5, r5[S_INDEX_BITREVERSING_ENABLED]
		bt r5, index_bitrev_order_0
			index_normal_order_0:
				SAVE_SAMPLES_NORMAL(S_FRAME_POINTER_0, 0);
				bu save_to_frame_complete_0
			index_bitrev_order_0:
				SAVE_SAMPLES_BIT_REVERSED(S_FRAME_POINTER_0);
		save_to_frame_complete_0:

		ldw r5, r4[S_FRAME_0_INDEX]
		{add r5, r5, 1;ldw r6, r4[S_OVERLAPPING_FRAMES]}
		stw r5, r4[S_FRAME_0_INDEX]

		bt r6, overlapping_frames
		no_overlapping_frames:

		ldw r6, r4[S_FRAME_SIZE_LOG2]
		{shr r5, r5, r6; ldc r6, 0}
		bf r5, do_the_rest;

			reset_the_frame_index:
			stw r6, r4[S_FRAME_0_INDEX]

			write_the_current_frames_metadata:

			ldd r7, r6, r4[S_D_FRAME_MIN_MAX_0]
	        ldw r5, r4[S_METADATA_POINTER_0]
	        std r7, r6, r5[0];
	        ldw r3, r4[S_FRAME_NUMBER]
	        {stw r3, r5[2]; add r3, r3, 1}	//if metadata layout changes then this needs to change too
	        stw r3, r4[S_FRAME_NUMBER]      //and save the new frame number back

			exchange_buffers:
			ldw r6, sp[S_C_OUTPUT]
			outct res[r6], 8 //WARNING: do not change this
			inct r3, res[r6]

	        eq r5, r3, EXCHANGE_BUFFERS		//if the incomming token is EXCHANGE_BUFFERS then do that
	        {bt r5, do_the_exchange; eq r5, r3, CONFIGURE_DECIMATOR}	//if the incomming token is CONFIGURE_DECIMATOR then do that

			ldap r11, configure
			stw r11, sp[0]
			ldw lr, sp[0]
			retsp 0

			do_the_exchange:
	        {in r3, res[r6]; ldc r0, 0}
	        {std r0, r3, r4[S_D_FRAME_POINTER_AND_INDEX_0]}

	        get_the_new_metadata_pointer:
	        {in r3, res[r6]}
	        {stw r3, r4[S_METADATA_POINTER_0]}
			std r0, r0, r4[S_D_FRAME_MIN_MAX_0]  //reset the frame min and max to 0

			ldw r4, sp[S_C_OUTPUT]
			outct res[r4], 8 //WARNING: do not change this
			no_overlapping_frames_done:
			bu do_the_rest

		overlapping_frames:

			ldaw r4, sp[S_FRAME_OFFSET]
			ldw r6, r4[S_FRAME_1_INDEX] //load second frame index

			ldaw r5, sp[S_OUTPUT_STORAGE];
			ldd r0, r1, r5[S_D_OUTPUT_STORAGE_01];
			ldd r2, r3, r5[S_D_OUTPUT_STORAGE_23];

			APPLY_WINDOW_FN(1)
			ldaw r4, sp[S_FRAME_OFFSET]
			ldw r6, r4[S_FRAME_1_INDEX] //load second frame index

			ldaw r5, sp[S_SETTINGS_OFFSET]
			ldw r5, r5[S_INDEX_BITREVERSING_ENABLED]
			bt r5, index_bitrev_order_1
				index_normal_order_1:
					SAVE_SAMPLES_NORMAL(S_FRAME_POINTER_1, 1);
					bu save_to_frame_complete_1
				index_bitrev_order_1:
					SAVE_SAMPLES_BIT_REVERSED(S_FRAME_POINTER_1);
			save_to_frame_complete_1:

			ldw r5, r4[S_FRAME_1_INDEX]
			{add r5, r5, 1;ldw r6, r4[S_FRAME_SIZE_LOG2]}
			stw r5, r4[S_FRAME_1_INDEX]


			{shr r5, r5, r6; ldc r6, 0}
			bf r5, do_the_rest;
			at_the_end_of_the_overlapping_half_frame:

				//set the metadata
/*
				ldd r7, r6, r4[S_D_FRAME_MIN_MAX_1]
		        ldw r5, r4[S_METADATA_POINTER_1]
		        std r7, r6, r5[0];
		        ldw r3, r4[S_FRAME_NUMBER]
		        {stw r3, r5[2]; add r3, r3, 1}	//if metadata layout changes then this needs to change too
*/
				ldw r6, sp[S_C_OUTPUT]
				outct res[r6], 8 //WARNING: do not change this

//		        stw r3, r4[S_FRAME_NUMBER]      //and save the new frame number back
				inct r11, res[r6]

		        eq r5, r11, EXCHANGE_BUFFERS		//if the incomming token is EXCHANGE_BUFFERS then do that
		        {bt r5, flip_the_frames; eq r5, r11, CONFIGURE_DECIMATOR}	//if the incomming token is CONFIGURE_DECIMATOR then do that

				ldap r11, configure
				stw r11, sp[0]
				ldw lr, sp[0]
				retsp 0

				flip_the_frames:
				ldd r3, r5, r4[S_D_FRAME_POINTER_AND_INDEX_0]
				std r3, r5, r4[S_D_FRAME_POINTER_AND_INDEX_1]
				ldd r3, r5, r4[S_D_FRAME_MIN_MAX_0]
				std r3, r5, r4[S_D_FRAME_MIN_MAX_1]

		        ldw r5, r4[S_METADATA_POINTER_0]
		        {in r3, res[r6]; ldc r0, 0}
		        stw r5, r4[S_METADATA_POINTER_1]

		        {std r0, r3, r4[S_D_FRAME_POINTER_AND_INDEX_0]}

		        get_the_new_metadata_pointer2:
		        {in r3, res[r6]}
		        {stw r3, r4[S_METADATA_POINTER_0]}
				std r0, r0, r4[S_D_FRAME_MIN_MAX_0]  //reset the frame min and max to 0

				ldw r4, sp[S_C_OUTPUT]
				outct res[r4], 8 //WARNING: do not change this

	do_the_rest:
	ldaw r11, sp[S_THIRD_STAGE]

	//copy accumulators to store
	{ldw r0, r11[7]  ; nop}
	{ldw r1, r11[9]	 ; nop}
	{ldw r2, r11[11] ; ldc r3, 13}
	{ldw r3, r11[r3] ; ldc r10, 0}

	ldaw r4, sp[S_OUTPUT_STORAGE];
	std r0, r1, r4[S_D_OUTPUT_STORAGE_01];
	std r2, r3, r4[S_D_OUTPUT_STORAGE_23];

	//set S_THIRD_STAGE_PHASE to 0
	stw r10, r11[S_THIRD_STAGE_PHASE];
	//reset accumulators
	std r10, r10, r11[S_D_THIRD_STAGE_CH0_ACC]
	std r10, r10, r11[S_D_THIRD_STAGE_CH1_ACC]
	std r10, r10, r11[S_D_THIRD_STAGE_CH2_ACC]
	std r10, r10, r11[S_D_THIRD_STAGE_CH3_ACC]

	//increment S_THIRD_STAGE_COEFS_PHASE mod THIRD_STAGE_COEFS_PER_STAGE
	ldw r10, r11[S_THIRD_STAGE_COEFS_PHASE]
	{add r10, r10, 1; ldc r9, THIRD_STAGE_COEFS_PER_STAGE}
	lsu r9, r10, r9
	mul r10, r10, r9
	stw r10, r11[S_THIRD_STAGE_COEFS_PHASE]
	retsp 0

.cc_bottom post_process.function
	.set	post_process.nstackwords, 0
	.globl	post_process.nstackwords
	.set	post_process.maxcores,1
	.globl	post_process.maxcores
	.set	post_process.maxtimers,0
	.globl	post_process.maxtimers
	.set	post_process.maxchanends,0
	.globl	post_process.maxchanends
.Lpost_process_tmp:
	.size	post_process, .Lpost_process_tmp-post_process
	.cfi_endproc

///////////////////////////////////////////////////////////////////////////////////////////

.globl	divide_by_four
.align	8
.type	divide_by_four,@function
.cc_top divide_by_four.function
divide_by_four:
	.cfi_startproc
	.issue_mode dual

	ldaw r10, sp[S_THIRD_STAGE]
	{ldw r8, sp[S_CHAN_COUNT];ldc r11, THIRD_STAGE_COEFS_PER_STAGE}	//r11 = 32
	mul r8, r8, r11
	{ldw r11, r10[S_THIRD_STAGE_PHASE]; shl r6, r11, 2}
	mul r8, r8, r11
	ldw r11, r10[S_THIRD_STAGE_COEFS_PHASE]
	{ldw r10, r10[S_THIRD_STAGE_DATA_POINTER];add r8, r8, r11}
	ldaw r10, r10[r8]

	ldw r8, sp[S_CHAN_COUNT]
	{dualentsp 1; eq r9, r8, 4}
	ldaw r11, cp[g_second_stage_fir]		//------------------------------------------------------------------------------------------------------------ This needs fixing

	{bt r9, mic_array_decimate_to_pcm_4ch_0; eq r9, r8, 3}
	{bt r9, mic_array_decimate_to_pcm_4ch_1; eq r9, r8, 2}
	{bt r9, mic_array_decimate_to_pcm_4ch_2; eq r9, r8, 1}
	{bt r9, mic_array_decimate_to_pcm_4ch_3;}
	bu divide_by_four_complete

	//r11 = coefs, r10 = pointer to where to put result, r7 = data, r6 = THIRD_STAGE_COEFS_PER_STAGE*sizeof(int)
mic_array_decimate_to_pcm_4ch_0:
	{bl mic_array_decimate_to_pcm_4ch_fir_impl ; }// data, coefs need to be set; h, l, c0, c1, d0, d1; return h(r0), l(r1);
	{stw r0, r10[0]; add r10, r10, r6}
mic_array_decimate_to_pcm_4ch_1:
	{bl mic_array_decimate_to_pcm_4ch_fir_impl ; add r7, r7, r6}// data, coefs need to be set; h, l, c0, c1, d0, d1; return h(r0), l(r1);
	{stw r0, r10[0]; add r10, r10, r6}
mic_array_decimate_to_pcm_4ch_2:
	{bl mic_array_decimate_to_pcm_4ch_fir_impl ; add r7, r7, r6}// data, coefs need to be set; h, l, c0, c1, d0, d1; return h(r0), l(r1);
	{stw r0, r10[0]; add r10, r10, r6}
mic_array_decimate_to_pcm_4ch_3:
	{bl mic_array_decimate_to_pcm_4ch_fir_impl ; add r7, r7, r6}// data, coefs need to be set; h, l, c0, c1, d0, d1; return h(r0), l(r1);
	stw r0, r10[0]

divide_by_four_complete:
	retsp 1
	.cc_bottom divide_by_four.function
	.set	divide_by_four.nstackwords, 1
	.globl	divide_by_four.nstackwords
	.set	divide_by_four.maxcores,1
	.globl	divide_by_four.maxcores
	.set	divide_by_four.maxtimers,0
	.globl	divide_by_four.maxtimers
	.set	divide_by_four.maxchanends,0
	.globl	divide_by_four.maxchanends
.Ldivide_by_four_tmp:
	.size	divide_by_four, .Ldivide_by_four_tmp-divide_by_four
	.cfi_endproc

///////////////////////////////////////////////////////////////////////////////////////////

////This is the actual implementation of the third stage FIR

.globl	third_stage_fir_impl
.align	8
.type	third_stage_fir_impl,@function
.cc_top third_stage_fir_impl.function
third_stage_fir_impl:
	.cfi_startproc
	.issue_mode dual

#define TWO_TAPS(I, COEFS, H0, L0, DATA0, H1, L1, DATA1)\
	{ldw r0, COEFS[0]; add COEFS, COEFS, 4};\
	ldd r2, r1, DATA0[I];\
	ldd r4, r3, DATA1[I];\
	maccs H0, L0, r1, r0;\
	maccs H1, L1, r3, r0;\
	{ldw r0, COEFS[0]; add COEFS, COEFS, 4};\
	maccs H0, L0, r2, r0;\
	maccs H1, L1, r4, r0

	TWO_TAPS(0, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(1, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(2, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(3, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(4, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(5, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(6, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(7, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(8, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(9, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(10, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(11, r9, r8, r7, r10, r6, r5, r11)
	ldc r0, 4*24
	{add r10, r10, r0; add r11, r11, r0}
	TWO_TAPS(0, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(1, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(2, r9, r8, r7, r10, r6, r5, r11)
	TWO_TAPS(3, r9, r8, r7, r10, r6, r5, r11)
	retsp 0
	.cc_bottom third_stage_fir_impl.function
	.set	third_stage_fir_impl.nstackwords, 0
	.globl	third_stage_fir_impl.nstackwords
	.set	third_stage_fir_impl.maxcores,1
	.globl	third_stage_fir_impl.maxcores
	.set	third_stage_fir_impl.maxtimers,0
	.globl	third_stage_fir_impl.maxtimers
	.set	third_stage_fir_impl.maxchanends,0
	.globl	third_stage_fir_impl.maxchanends
.Lthird_stage_fir_impl_tmp:
	.size	third_stage_fir_impl, .Lthird_stage_fir_impl_tmp-third_stage_fir_impl
	.cfi_endproc

///////////////////////////////////////////////////////////////////////////////////////////

////This is the actual implementation of the second stage FIR

.globl	mic_array_decimate_to_pcm_4ch_fir_impl
.align	8
.type	mic_array_decimate_to_pcm_4ch_fir_impl,@function
.cc_top mic_array_decimate_to_pcm_4ch_fir_impl.function
mic_array_decimate_to_pcm_4ch_fir_impl:
	.cfi_startproc
	.issue_mode dual

	//r0, r1, r2, r3, r4, r5, r6 = 31, r7, r10, r11,
	{ldc r0, 0; ldc r1, 0} //Initialise the accumulators

	ldd r3, r2, r11[0]
	ldd r5, r4, r7[0]
	maccs r0, r1, r4, r2
	maccs r0, r1, r5, r3
	ldd r5, r4, r7[7]
	maccs r0, r1, r4, r3
	maccs r0, r1, r5, r2

	ldd r3, r2, r11[1]
	ldd r5, r4, r7[1]
	maccs r0, r1, r4, r2
	maccs r0, r1, r5, r3
	ldd r5, r4, r7[6]
	maccs r0, r1, r4, r3
	maccs r0, r1, r5, r2

	ldd r3, r2, r11[2]
	ldd r5, r4, r7[2]
	maccs r0, r1, r4, r2
	maccs r0, r1, r5, r3
	ldd r5, r4, r7[5]
	maccs r0, r1, r4, r3
	maccs r0, r1, r5, r2

	ldd r3, r2, r11[3]
	ldd r5, r4, r7[3]
	maccs r0, r1, r4, r2
	maccs r0, r1, r5, r3
	ldd r5, r4, r7[4]
	maccs r0, r1, r4, r3
	maccs r0, r1, r5, r2

	retsp 0
	.cc_bottom mic_array_decimate_to_pcm_4ch_fir_impl.function
	.set	mic_array_decimate_to_pcm_4ch_fir_impl.nstackwords, 0
	.globl	mic_array_decimate_to_pcm_4ch_fir_impl.nstackwords
	.set	mic_array_decimate_to_pcm_4ch_fir_impl.maxcores,1
	.globl	mic_array_decimate_to_pcm_4ch_fir_impl.maxcores
	.set	mic_array_decimate_to_pcm_4ch_fir_impl.maxtimers,0
	.globl	mic_array_decimate_to_pcm_4ch_fir_impl.maxtimers
	.set	mic_array_decimate_to_pcm_4ch_fir_impl.maxchanends,0
	.globl	mic_array_decimate_to_pcm_4ch_fir_impl.maxchanends
.Lmic_array_decimate_to_pcm_4ch_fir_impl_tmp:
	.size	mic_array_decimate_to_pcm_4ch_fir_impl, .Lmic_array_decimate_to_pcm_4ch_fir_impl_tmp-mic_array_decimate_to_pcm_4ch_fir_impl

.cfi_endproc

//This is for testing the DC offset elimination
//void dc_eliminate_tester(int &x, long long &y)
.globl	dc_eliminate_tester
.align	8
.type	dc_eliminate_tester,@function
.cc_top dc_eliminate_tester.function
dc_eliminate_tester:
	.cfi_startproc
	.issue_mode dual
	dualentsp 16

	std r4, r5, sp[2]
	std r6, r7, sp[3]
	std r8, r9, sp[4]
	std r10, r11, sp[5]

	ldw r2, r0[0]
	mov r4, r1
	DC_OFFSET_REMOVAL(S_D_PREV_Y_0, S_PREV_X_0, r2); //TODO setup the last arg
	stw r2, r0[0]

	ldd r4, r5, sp[2]
	ldd r6, r7, sp[3]
	ldd r8, r9, sp[4]
	ldd r10, r11, sp[5]

	retsp 16
	.cc_bottom dc_eliminate_tester.function
	.set	dc_eliminate_tester.nstackwords, 16
	.globl	dc_eliminate_tester.nstackwords
	.set	dc_eliminate_tester.maxcores,1
	.globl	dc_eliminate_tester.maxcores
	.set	dc_eliminate_tester.maxtimers,0
	.globl	dc_eliminate_tester.maxtimers
	.set	dc_eliminate_tester.maxchanends,0
	.globl	dc_eliminate_tester.maxchanends
.Ldc_eliminate_tester_tmp:
	.size	dc_eliminate_tester, .Ldc_eliminate_tester_tmp-dc_eliminate_tester
	.cfi_endproc

	//endpoint section

#define STRINGIZE(S) #S

#define EP_MARCO(ID, PASS) \
	.ascii	STRINGIZE( input_ ## ID ## _ ## PASS ## _ep ) ;\
	.byte	0 ;\
	.ascii	"" ;\
	.byte	0 ;\
	.long	0 ;\
	.long	.Laddr_end ## ID ## _ ## PASS ## -.Laddr_start ## ID ## _ ## PASS;\
	.Laddr_start ## ID ## _ ## PASS : ;\
	.cc_top cc_ ## ID ## _ ## PASS ## ,input_ ## ID ## _ ## PASS ;\
	.long	input_ ## ID ## _ ## PASS ;\
	.byte	0 ;\
	.cc_bottom cc_ ## ID ## _ ## PASS ;\
	.Laddr_end ## ID ## _ ## PASS :

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
	EP_MARCO(0, 0)
	EP_MARCO(1, 0)
	EP_MARCO(2, 0)
	EP_MARCO(3, 0)
	EP_MARCO(4, 0)
	EP_MARCO(5, 0)
	EP_MARCO(6, 0)
	EP_MARCO(7, 0)
	EP_MARCO(0, 1)
	EP_MARCO(1, 1)
	EP_MARCO(2, 1)
	EP_MARCO(3, 1)
	EP_MARCO(4, 1)
	EP_MARCO(5, 1)
	EP_MARCO(6, 1)
	EP_MARCO(7, 1)
.Laddr_end9:

.Lentries_end0:

	.section	.xtaendpointtable,"",@progbits
.Lentries_start1:
	.long	.Lentries_end1-.Lentries_start1
	.long	0
	.ascii	""
	.byte	0
	EPT_MARCO(0, 0)
	EPT_MARCO(1, 0)
	EPT_MARCO(2, 0)
	EPT_MARCO(3, 0)
	EPT_MARCO(4, 0)
	EPT_MARCO(5, 0)
	EPT_MARCO(6, 0)
	EPT_MARCO(7, 0)
	EPT_MARCO(0, 1)
	EPT_MARCO(1, 1)
	EPT_MARCO(2, 1)
	EPT_MARCO(3, 1)
	EPT_MARCO(4, 1)
	EPT_MARCO(5, 1)
	EPT_MARCO(6, 1)
	EPT_MARCO(7, 1)
.Lentries_end1:
