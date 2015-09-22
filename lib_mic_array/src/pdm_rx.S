	.section	.dp.data,"awd",@progbits
	.text
	.cc_top pdm_rx_with_hires_delay_asm.function
	.globl	pdm_rx_with_hires_delay_asm
	.align	4
	.type	pdm_rx_with_hires_delay_asm,@function
	.issue_mode dual

#define p_pdm_mics 			 r0
#define mask 		 		 r1
#define expander			 r2
#define c_4x_pdm_mic_1       r3
#define c_4x_pdm_mic_0		 r4

#define c_sync			     r5
#define index			 	 r6
#define memory_depth_log2	 r7

#define a		     		 r8
#define b		     		 r9
#define s			 		 r10
#define t			 		 r11

//Stack
#define STACKWORDS 8

#define S_INT_0 1
#define S_INT_1 2
#define S_EXPANDER 4

#define INTEGRATE() \
	{in t, res[p_pdm_mics]; ldw s, sp[S_EXPANDER]};\
	ldd s, t, s[t];\
    ldd a, b, sp[S_INT_0];\
	{add a, a, s; add b, b, t};\
	{and a, a, mask; and b, b, mask};\
	std a, b, sp[S_INT_0];\
	ldd s, t, sp[S_INT_1];\
	{add s, s, a; add t, t, b};\
	{and s, s, mask; and t, t, mask};\
	std s, t, sp[S_INT_1];\

pdm_rx_with_hires_delay_asm://(
		// in port p_pdm_mics,
		// unsigned long long * shared_memory_array,
		// unsigned ch_memory_depth_log2,
		// streaming chanend c_sync,
		// streaming chanend c_4x_pdm_mic_0,
        // streaming chanend c_4x_pdm_mic_1)

.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

	ldaw t, cp[g_expand]
	mov expander, t

	mov memory_depth_log2, r2
	ldw c_4x_pdm_mic_1, sp[1+STACKWORDS]
	ldw c_4x_pdm_mic_0, sp[2+STACKWORDS]

	ldw mask, cp[cic_mask]

	//Initialise the integrators
	ldc index, 0
	std index, index, sp[S_INT_0]
	std index, index, sp[S_INT_1]

	.align 8
pdm_rx_with_hires_delay_loop:
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	std s, t, t[index];
	{outct res[c_sync], 0; add index, index, 1}
	{out res[c_4x_pdm_mic_0], s; zext index, memory_depth_log2}
	{out res[c_4x_pdm_mic_1], t; bl pdm_rx_with_hires_delay_loop}

.pdm_rx_with_hires_delay_asm_tmp:
	.size	pdm_rx_with_hires_delay_asm, .pdm_rx_with_hires_delay_asm_tmp-pdm_rx_with_hires_delay_asm
	.align	4
	.cc_bottom pdm_rx_with_hires_delay_asm.function

	.set	pdm_rx_with_hires_delay_asm.nstackwords,STACKWORDS
	.globl	pdm_rx_with_hires_delay_asm.nstackwords
	.set	pdm_rx_with_hires_delay_asm.maxcores,1
	.globl	pdm_rx_with_hires_delay_asm.maxcores
	.set	pdm_rx_with_hires_delay_asm.maxtimers,0
	.globl	pdm_rx_with_hires_delay_asm.maxtimers
	.set	pdm_rx_with_hires_delay_asm.maxchanends,0
	.globl	pdm_rx_with_hires_delay_asm.maxchanends

		.cc_top pdm_rx_asm.function
	.globl	pdm_rx_asm
	.align	4
	.type	pdm_rx_asm,@function
pdm_rx_asm://(
        //in buffered port:8 p_pdm_mics,
        //streaming chanend c_4x_pdm_mic_0,
        //streaming chanend c_4x_pdm_mic_1);

.issue_mode dual
	DUALENTSP_lu6 STACKWORDS
	{mov c_4x_pdm_mic_1, r1;mov c_4x_pdm_mic_0, r2}
	ldaw t, cp[g_expand]
	mov expander, t
	ldw mask, cp[cic_mask]

	//Initialise the integrators
	ldc a, 0
	std a, a, sp[S_INT_0]
	std a, a, sp[S_INT_1]
	.align 8
pdm_rx_loop:
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()

	{out res[c_4x_pdm_mic_0], s;}
	{out res[c_4x_pdm_mic_1], t; bl pdm_rx_loop}

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


		.cc_top pdm_rx_only_hires_delay_asm.function
	.globl	pdm_rx_only_hires_delay_asm
	.align	4
	.type	pdm_rx_only_hires_delay_asm,@function
pdm_rx_only_hires_delay_asm://{
        //in buffered port:8 p_pdm_mics,
        //unsigned long long * unsafe shared_memory_array,
        //unsigned ch_memory_depth_log2,
        //streaming chanend c_sync);

.issue_mode dual
	DUALENTSP_lu6 STACKWORDS

	ldaw t, cp[g_expand]
	mov expander, t

	mov memory_depth_log2, r2

	ldw mask, cp[cic_mask]

	//Initialise the integrators
	ldc index, 0
	std index, index, sp[S_INT_0]
	std index, index, sp[S_INT_1]

	.align 8

pdm_rx_only_hires_delay_loop:
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	INTEGRATE()
	std s, t, t[index];
	{outct res[c_sync], 0; add index, index, 1}
	{zext index, memory_depth_log2; bl pdm_rx_only_hires_delay_loop}

.pdm_rx_only_hires_delay_asm_tmp:
	.size	pdm_rx_only_hires_delay_asm, .pdm_rx_only_hires_delay_asm_tmp-pdm_rx_only_hires_delay_asm
	.align	4
	.cc_bottom pdm_rx_only_hires_delay_asm.function

	.set	pdm_rx_only_hires_delay_asm.nstackwords,STACKWORDS
	.globl	pdm_rx_only_hires_delay_asm.nstackwords
	.set	pdm_rx_only_hires_delay_asm.maxcores,1
	.globl	pdm_rx_only_hires_delay_asm.maxcores
	.set	pdm_rx_only_hires_delay_asm.maxtimers,0
	.globl	pdm_rx_only_hires_delay_asm.maxtimers
	.set	pdm_rx_only_hires_delay_asm.maxchanends,0
	.globl	pdm_rx_only_hires_delay_asm.maxchanends
