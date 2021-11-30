// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <xclib.h>
#include <stdlib.h>
#include <platform.h>
#include <string.h>
#include <print.h>
#include "mic_array.h"                    //FRAME SIZE and coeffs
extern const int [[aligned(8)]] g_third_stage_div_6_fir_dual[192]; //From fir_coefs_dual.xc. We make a LL aligned copy of this
#include "dsp_qformat.h"                  //Gain compensation

#if (defined(MIC_DUAL_ENABLED) && (MIC_DUAL_ENABLED == 0))
#undef MIC_DUAL_ENABLED
#endif

#ifndef MIC_DUAL_ENABLED
    #ifdef MIC_DUAL_FRAME_SIZE
        #error "Set MIC_DUAL_ENABLED to 1."
    #endif
#endif

#define MIC_DUAL_OUTPUT_BLOCK_SIZE        MIC_DUAL_FRAME_SIZE
#define MIC_DUAL_GAIN_COMPENSATION        2.117307f     //Value needed to bring mic level up to inputNear[] compared with lib_mic_array
                                                        //Max is 7.999 due to Q28 format
#ifndef MIC_DUAL_NUM_OUT_BUFFERS
  #define MIC_DUAL_NUM_OUT_BUFFERS          2             //Single (1) or double (2) buffered
#endif
#define MIC_DUAL_NUM_CHANNELS             2             //Always 2 because it's a pair of mics we are decimating
#define MIC_DUAL_NUM_REF_CHANNELS         2             //Always 2 in xvf3510 case


#pragma unsafe arrays
//This effectively implements a delayline of 6 chars of bits, the later three reversed
static inline int first_stage_fir(unsigned char pdm, unsigned delay_line[]){

  //Move delay line along one byte (8 x 1b samples) and insert 8 pdm bits at bottom
  //Top (oldest) byte is not directly used but instead reversed and copied by next stage
  delay_line[0] <<= 8;
  delay_line[0] |= pdm;

  //Oldest 8b pops into top, bitrev it and add to the second, reverse part of delay line
  //We do not use the MSB of this word
  unsigned tmp = bitrev(delay_line[0]);
  tmp &= 0xff;
  delay_line[1] <<= 8;
  delay_line[1] |= tmp; 

  //Do the 6 (* 8) dot products and accumulate
  int accumulator = 0;
  unsigned char * delayline_ptr = (unsigned char *)&delay_line;
  accumulator += g_first_stage_fir_0[*(delayline_ptr + 0)];
  accumulator += g_first_stage_fir_0[*(delayline_ptr + 6)];
  accumulator += g_first_stage_fir_1[*(delayline_ptr + 1)];
  accumulator += g_first_stage_fir_1[*(delayline_ptr + 5)];
  accumulator += g_first_stage_fir_2[*(delayline_ptr + 2)];
  accumulator += g_first_stage_fir_2[*(delayline_ptr + 4)];

  return accumulator;
}


//16 tap FIR for middle stage (384kHz -> 96kHz)
#pragma unsafe arrays
static inline int mid_stage_fir(const int mid_stage_fir[], int mid_stage_delay[], unsigned mid_stage_delay_idx){
  unsafe{
    int ah = 0;
    unsigned al = 0;
    int c0, c1, s0, s1;

    int * unsafe filter_ptr = (int*)mid_stage_fir;
    int * unsafe state_ptr = &mid_stage_delay[mid_stage_delay_idx];

    unsigned format = 32; //for extract
    //Note because FIR is symmetrical, we only need load the first half of the coeffs 
    //and we do not need to reload them into registers, so it's very fast (2.5 cyc per MAC)

    //stages 0, 1, 14, 15
    asm volatile("ldd %0,%1,%2[0]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
    asm volatile("ldd %0,%1,%2[0]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

    asm volatile("ldd %0,%1,%2[7]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s1),"0"(ah),"1"(al));


    //stages 2, 3, 12, 13
    asm volatile("ldd %0,%1,%2[1]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
    asm volatile("ldd %0,%1,%2[1]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

    asm volatile("ldd %0,%1,%2[6]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s1),"0"(ah),"1"(al));


    //stages 4, 5, 10, 11
    asm volatile("ldd %0,%1,%2[2]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
    asm volatile("ldd %0,%1,%2[2]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

    asm volatile("ldd %0,%1,%2[5]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s1),"0"(ah),"1"(al));


    //stages 6, 7, 8, 9
    asm volatile("ldd %0,%1,%2[3]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
    asm volatile("ldd %0,%1,%2[3]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

    asm volatile("ldd %0,%1,%2[4]":"=r"(s0),"=r"(s1):"r"(state_ptr));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s0),"0"(ah),"1"(al));
    asm volatile("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s1),"0"(ah),"1"(al));


    //extract and saturate
    asm volatile("lsats %0,%1,%2":"=r"(ah),"=r"(al):"r"(format),"0"(ah),"1"(al));
    asm volatile("lextract %0,%1,%2,%3,32":"=r"(ah):"r"(ah),"r"(al),"r"(format));

    return ah;
  }
}


//POLY FIR 192 Taps by 6 = 32 taps per stage
//Note this expects the coeffs in reverse order
#pragma unsafe arrays
unsafe static inline int final_stage_poly_fir(
  int input_sample,
  int delayline[], 
  int * unsafe filter_ptr)
{

  int ah = 0;
  unsigned al = 0;
  int c0, c1, s0 = input_sample, s1, s2, s3;


  int * unsafe state_ptr;
  unsafe{
    state_ptr = (int * unsafe)delayline;
    //printf("state: 0x%x filter: 0x%x\n", state_ptr, filter_ptr);
  }

  unsigned format = 32; //for extract

  unsafe{
    filter_ptr += 16;
  }

  asm("ldd %0,%1,%2[7]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[0]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[0]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[6]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[1]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[1]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[5]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[2]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[2]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[4]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[3]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[3]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[3]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[4]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[4]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[2]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[5]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[5]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[1]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[6]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[6]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[0]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[7]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[7]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));


  unsafe{
    filter_ptr -= 16;
    state_ptr += 16;
  }

  asm("ldd %0,%1,%2[7]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[0]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[0]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[6]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[1]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[1]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[5]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[2]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[2]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[4]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[3]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[3]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[3]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[4]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[4]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[2]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[5]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[5]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[1]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[6]":"=r"(s2),"=r"(s1):"r"(state_ptr));
  asm("std %0,%1,%2[6]"::"r"(s1), "r"(s0),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s0),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s1),"0"(ah),"1"(al));

  asm("ldd %0,%1,%2[0]":"=r"(c0),"=r"(c1):"r"(filter_ptr));
  asm("ldd %0,%1,%2[7]":"=r"(s0),"=r"(s3):"r"(state_ptr));
  asm("std %0,%1,%2[7]"::"r"(s3), "r"(s2),"r"(state_ptr));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c0),"r"(s2),"0"(ah),"1"(al));
  asm("maccs %0,%1,%2,%3":"=r"(ah),"=r"(al):"r"(c1),"r"(s3),"0"(ah),"1"(al));

  asm("lsats %0,%1,%2":"=r"(ah),"=r"(al):"r"(format),"0"(ah),"1"(al));
  asm("lextract %0,%1,%2,%3,32":"=r"(ah):"r"(ah),"r"(al),"r"(format));

  return ah;
}

//This block copies the 4 ints from the first stage into stage two FIR state array
//Optimised to 64b using double load/store. Assumes 8 byte alignment.
//It allows the stage 2 FIR to blast straight through without shifting the delay line
static inline void ciruclar_buffer_sim_cpy(int * unsafe src_ptr, int * unsafe dest_ptr){
  unsafe{
    int tmp_0, tmp_1;
    //Copy first 2 words
    asm volatile("ldd %0,%1,%2[0]":"=r"(tmp_1),"=r"(tmp_0):"r"(src_ptr));
    asm volatile("std %0,%1,%2[0]"::"r"(tmp_1), "r"(tmp_0),"r"(dest_ptr));
    asm volatile("std %0,%1,%2[8]"::"r"(tmp_1), "r"(tmp_0),"r"(dest_ptr));
    //Copy second 2 words
    asm volatile("ldd %0,%1,%2[1]":"=r"(tmp_1),"=r"(tmp_0):"r"(src_ptr));
    asm volatile("std %0,%1,%2[1]"::"r"(tmp_1), "r"(tmp_0),"r"(dest_ptr));
    asm volatile("std %0,%1,%2[9]"::"r"(tmp_1), "r"(tmp_0),"r"(dest_ptr));
  }
}


// If not MIC_DUAL_ENABLED, cause a link error
#ifdef MIC_DUAL_ENABLED

static int dc_eliminate(int x, int &prev_x, long long &state){
#define S 0
#define N 8
    long long X = x;
    long long prev_X = prev_x;

    state = state - (state>>8);

    prev_X<<=32;
    state = state - prev_X;

    X<<=32;
    state = state + X;

    prev_x = x;

    return (state>>(32-S));
}


#pragma unsafe arrays
void mic_dual_pdm_rx_decimate(buffered in port:32 p_pdm_mic, streaming chanend c_2x_pdm_mic, streaming chanend c_ref_audio[]){

  //Send initial request to UBM
  c_ref_audio[0] <: 0;
  c_ref_audio[1] <: 0;

  unsigned delay_line[MIC_DUAL_NUM_CHANNELS][2] = {{0xaaaaaaaa, 0x55555555}, {0xaaaaaaaa, 0x55555555}}; //48 taps, init to pdm zero
  int [[aligned(8)]] out_first_stage[MIC_DUAL_NUM_CHANNELS][4] = {{0}};

  unsigned mid_stage_delay_idx = 0;
  const unsigned mid_stage_decimation_factor = 4;
  const unsigned mid_stage_ntaps = 16;
  int [[aligned(8)]] mid_stage_delay[MIC_DUAL_NUM_CHANNELS][16 * 2]; //Double length for circular buffer simulation
  memset(mid_stage_delay, 0, sizeof(mid_stage_delay));

  int final_stage_in_pcm[MIC_DUAL_NUM_CHANNELS] = {0, 0};

  unsigned block_sample_count = 0;  //Used for assembling blocks from individual samples
  unsigned block_buffer_idx = 0;    //Optional double buffer for output blocks

  int * unsafe phase_coeff_ptrs[6];
  int [[aligned(8)]] final_stage_delay_poly[MIC_DUAL_NUM_CHANNELS][6][32] = {{{0}}};
  memset(final_stage_delay_poly, 0, sizeof(final_stage_delay_poly));
  unsigned final_stage_phase = 0;

  int pcm_output[MIC_DUAL_NUM_CHANNELS] = {0, 0};

  int dc_elim_prev[MIC_DUAL_NUM_CHANNELS] = {0, 0};
  long long dc_elim_state[MIC_DUAL_NUM_CHANNELS] = {0, 0};


  int output_block[MIC_DUAL_NUM_OUT_BUFFERS][MIC_DUAL_OUTPUT_BLOCK_SIZE][MIC_DUAL_NUM_CHANNELS + MIC_DUAL_NUM_REF_CHANNELS];
  memset(output_block, 0, sizeof(output_block));

  //Setup nice array of pointers for each phase of coefficients
  unsafe{
    for(int i = 0; i < 6; i++) phase_coeff_ptrs[i] = (int * unsafe)&g_third_stage_div_6_fir_dual[i * 32];
  }

  //We are reading in 2 x 32b values in one chunk every 10.4us (96kHz) so we need to 32b storage elements
  unsigned port_data[2];

  while(1) unsafe{
    unsigned t0, t1;
    timer t;

    //GET PORT DATA
    asm volatile("in %0, res[%1]" : "=r"(port_data[0])  : "r"(p_pdm_mic)); //Use ASM so we avoid SETC instruction
    //Input comes in from bit 31 (MSb) and shifts right, so LSB is oldest
    t :> t0;

    //UNZIP INTO TWO PDM STREAMS
    unsigned long long tmp64 = (unsigned long long) (port_data[0]) << 32 | port_data[1];
    {port_data[0], port_data[1]} = unzip(tmp64, 0);

    //DO FIRST STAGE FIR AND POPULATE BUFFER FOR MID STAGE
#pragma loop unroll
    for (int i = 0; i < 4; i++){
      #pragma loop unroll
      for (int ch = 0; ch < MIC_DUAL_NUM_CHANNELS; ch++){
        unsigned char pdm = port_data[ch] >> (8 * i);
        //printbinln(pdm);
        int out_first_stage_tmp = first_stage_fir(pdm, delay_line[ch]);
        out_first_stage[ch][i] = out_first_stage_tmp;
        //printintln(out_first_stage_tmp);

      }
    }
   
    //CALL MID STAGE FIR
    #pragma loop unroll
    for (int ch = 0; ch < MIC_DUAL_NUM_CHANNELS; ch++){
      int * first_stage_out_src_ptr = out_first_stage[ch];
      ciruclar_buffer_sim_cpy(first_stage_out_src_ptr, (int * unsafe)&mid_stage_delay[ch][mid_stage_delay_idx]);
    }
    mid_stage_delay_idx += mid_stage_decimation_factor; //Increment before FIR so we get a proper buffer history 

    #pragma loop unroll
    for (int ch = 0; ch < MIC_DUAL_NUM_CHANNELS; ch++){
      final_stage_in_pcm[ch] = mid_stage_fir(g_second_stage_fir, mid_stage_delay[ch], mid_stage_delay_idx);
    }
    //printintln(final_stage_in_pcm[0]);
    if (mid_stage_delay_idx == mid_stage_ntaps) {
      mid_stage_delay_idx = 0;
    }

    //CALL FINAL STAGE POLYPHASE FIR
    #pragma loop unroll
    for (int ch = 0; ch < MIC_DUAL_NUM_CHANNELS; ch++){
      pcm_output[ch] += final_stage_poly_fir(final_stage_in_pcm[ch], final_stage_delay_poly[ch][final_stage_phase], phase_coeff_ptrs[final_stage_phase]);
    }

    //Move on phase of polyFIR and reset if done
    final_stage_phase++;
    if (final_stage_phase == 6) unsafe{
      //printintln(pcm_output[0]);

      //If we have reached stage 6 then we are ready to send a pair of decimated 16kHz mic signals
      //and also receive reference audio
      unsigned ref_audio[MIC_DUAL_NUM_REF_CHANNELS];
      select{
        case c_ref_audio[0] :> ref_audio[0]:
          for (int ch = 1; ch < MIC_DUAL_NUM_REF_CHANNELS; ch++) c_ref_audio[ch] :> ref_audio[ch];
          //Request some more samples
          for (int ch = 0; ch < MIC_DUAL_NUM_REF_CHANNELS; ch++) c_ref_audio[ch] <: 0;
        break;
        default:
        //The host doesn't start sending ref audio for a while at startup so we have to be prepared for nothing on channel
        //printstr("."); //This is debug and can be removed
        #pragma loop unroll
        for (int ch = 0; ch < MIC_DUAL_NUM_REF_CHANNELS; ch++){
            ref_audio[ch] = 0;
        }
        break;
      }

      #pragma loop unroll
      for (int ch = 0; ch < MIC_DUAL_NUM_CHANNELS; ch++){
        //Now remove DC and apply some gain
        pcm_output[ch] = dc_eliminate(pcm_output[ch], dc_elim_prev[ch], dc_elim_state[ch]);
        pcm_output[ch] = (int)( ( (long long)pcm_output[ch] * Q28(MIC_DUAL_GAIN_COMPENSATION) ) >> (28));
        output_block[block_buffer_idx][block_sample_count][ch] = pcm_output[ch];
      }
      for (int ch = 0; ch < MIC_DUAL_NUM_REF_CHANNELS; ch++){
        output_block[block_buffer_idx][block_sample_count][MIC_DUAL_NUM_CHANNELS + ch] = ref_audio[ch];
      }
      block_sample_count++;
      //We have assembled a block so pass a pointer to the consumer
      if (block_sample_count == MIC_DUAL_OUTPUT_BLOCK_SIZE){
        c_2x_pdm_mic <: (unsigned)output_block[block_buffer_idx];        
        block_sample_count = 0;
        block_buffer_idx ^= (MIC_DUAL_NUM_OUT_BUFFERS - 1); //Toggle if double buffer, else do nothing
      }
      #pragma loop unroll
      for (int ch = 0; ch < MIC_DUAL_NUM_CHANNELS; ch++){
        pcm_output[ch] = 0;
      }
      final_stage_phase = 0;
    }
    asm volatile("in %0, res[%1]" : "=r"(port_data[1])  : "r"(p_pdm_mic));

    t :> t1;
    //Cycle time at 96kHz is 1041 10ns ticks, which is 650 proc cycles
    //if (t1-t0 > 600) printintln(t1-t0);
    //printintln(t1-t0);
  }
}
#endif
