	.section	.dp.data,"awd",@progbits
	.text
#define p_pdm_mics 			 r0
#define c_4x_pdm_mic_1       r1
#define c_4x_pdm_mic_0		 r2
#define mask 		 		 r3

#define buffer	 			 r4
#define p	 			     r5
#define q	 			     r6
#define index	 			 r7

#define a		     		 r8
#define b		     		 r9
#define s			 		 r10
#define t			 		 r11

//Stack
#define STACKWORDS 32

#define S_INT_0  0
#define S_INT_1  1
#define S_INT_2  2
#define S_COMB_0 3
#define S_COMB_1 4
#define S_COMB_2 5
#define S_MEM_CHAN 6
#define S_MEM_LOG2 14

#define INIT_STACK() \
	ldc a, 0;\
	std a, a, sp[S_INT_0];\
	std a, a, sp[S_INT_1];\
	std a, a, sp[S_INT_2];\
	std a, a, sp[S_COMB_0];\
	std a, a, sp[S_COMB_1];\
	std a, a, sp[S_COMB_2]


#define INTEGRATE() \
	ldd s, t, t[s];\
    ldd a, b, sp[S_INT_0];\
	{add a, a, s; add b, b, t};\
	{and a, a, mask; and b, b, mask};\
	std a, b, sp[S_INT_0];\
	ldd s, t, sp[S_INT_1];\
	{add s, s, a; add t, t, b};\
	{and s, s, mask; and t, t, mask};\
	std s, t, sp[S_INT_1];\
    ldd a, b, sp[S_INT_2];\
	{add a, a, s; add b, b, t};\
	{and a, a, mask; and b, b, mask};\
	std a, b, sp[S_INT_2];

#define COMB() \
	{add s, a, mask; add t, b, mask};\
	ldd p, q, sp[S_COMB_0];\
	{sub s, s, p; sub t, t, q};\
	std a, b, sp[S_COMB_0];\
	{and s, s, mask; and t, t, mask};\
	{add a, s, mask; add b, t, mask};\
	ldd p, q, sp[S_COMB_1];\
	{sub a, a, p; sub b, b, q};\
	std s, t, sp[S_COMB_1];\
	{and a, a, mask; and b, b, mask};\
	{add s, a, mask; add t, b, mask};\
	ldd p, q, sp[S_COMB_2];\
	{sub s, s, p; sub t, t, q};\
	std a, b, sp[S_COMB_2];\
	{and s, s, mask; and t, t, mask};


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
	ldw mask, cp[cic_mask]
	INIT_STACK()

	.align 8
pdm_rx_loop:
	{in buffer, res[p_pdm_mics]; nop}
	{mov s, buffer; nop}
	{zext s, 8; ldaw t, cp[g_expand]}
	INTEGRATE()
	{shr s, buffer, 8; nop}
	{zext s, 8; ldaw t, cp[g_expand]}
	INTEGRATE()
	{shr s, buffer, 16; nop}
	{zext s, 8; ldaw t, cp[g_expand]}
	INTEGRATE()
	{shr s, buffer, 24; ldaw t, cp[g_expand]}
	INTEGRATE()

	COMB()

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
	std r3, r1, sp[S_MEM_CHAN]
	stw r2, sp[S_MEM_LOG2]
	ldc index, 0
	ldw mask, cp[cic_mask]
	INIT_STACK()

	.align 8
pdm_rx_only_hires_delay_loop:
	{in buffer, res[p_pdm_mics]; nop}
	{mov s, buffer; nop}
	{zext s, 8; ldaw t, cp[g_expand]}
	INTEGRATE()
	{shr s, buffer, 8; nop}
	{zext s, 8; ldaw t, cp[g_expand]}
	INTEGRATE()
	{shr s, buffer, 16; nop}
	{zext s, 8; ldaw t, cp[g_expand]}
	INTEGRATE()
	{shr s, buffer, 24; ldaw t, cp[g_expand]}
	INTEGRATE()

	COMB()

	ldd a, b, sp[S_MEM_CHAN]
	std s, t, b[index];
	{outct res[a], 0; add index, index, 1}
	ldw a, sp[S_MEM_LOG2]
	{zext index, a; bl pdm_rx_only_hires_delay_loop}

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



