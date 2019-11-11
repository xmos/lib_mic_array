// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <string.h>
#include "mic_array.h"

//Note XMOS test runs from directory up hence adding dir to filename
//Expects binary file with one byte per bit. Byte value is either 0 or 1
#define PDM_FILE_NAME_A "test_mic_dual/ch_a.pdm"
#define PDM_FILE_NAME_B "test_mic_dual/ch_b.pdm"

#define PCM_FILE_NAME_STD_A "test_mic_dual/ch_a_std.raw"
#define PCM_FILE_NAME_STD_B "test_mic_dual/ch_b_std.raw"

#define PCM_FILE_NAME_DUAL_A "test_mic_dual/ch_a_dual.raw"
#define PCM_FILE_NAME_DUAL_B "test_mic_dual/ch_b_dual.raw"

in buffered port:32 p_pdm_mics   = XS1_PORT_1A;
unsafe{
    buffered port:32 * unsafe p_ptr = (buffered port:32 * unsafe) &p_pdm_mics;
}

//Note unusual casting of channel to a port. i.e. we output directly onto channel rather than port
unsafe{
    void call_mic_dual_pdm_rx_decimate(chanend c_mic_dual_pdm, streaming chanend c_ds_output[], streaming chanend c_ref_audio[]){
        p_ptr = ( buffered port:32 * unsafe ) &c_mic_dual_pdm;
        //printf("%p\n", *p_ptr);
        mic_dual_pdm_rx_decimate(*p_ptr, c_ds_output[0], c_ref_audio);
    }
}

extern void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

unsafe{
    void call_pdm_rx(chanend c_mic_dual_pdm, streaming chanend c_4x_pdm_mic_0, streaming chanend ?c_4x_pdm_mic_1){
        p_ptr = ( buffered port:32 * unsafe ) &c_mic_dual_pdm;
        //printf("%p\n", *p_ptr);
        mic_array_pdm_rx(*p_ptr, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
    }
}


void get_pdm_from_file(chanend c_mic_dual_pdm, streaming chanend c_mic_array_pdm){
  FILE * unsafe pdm_file[2];
  pdm_file[0] = fopen ( PDM_FILE_NAME_A , "rb" );
  pdm_file[1] = fopen ( PDM_FILE_NAME_B , "rb" );


  if ((pdm_file[0]==NULL)) {
      printf("cannot open (%s)\n", PDM_FILE_NAME_A);
      exit(1);
  }
  if ((pdm_file[1]==NULL)) {
      printf("cannot open (%s)\n", PDM_FILE_NAME_B);
      exit(1);
  }

  //Get size of first file (assume they are the same size)
  fseek(pdm_file[0], 0L, SEEK_END);
  unsigned sz = ftell(pdm_file[0]);
  rewind(pdm_file[0]);

  unsigned pdm_word_count = 0;
  unsigned char pdm_chunk[2][32];
  while(1){
    if (32 != fread (pdm_chunk[0], 1, 32, (FILE *)pdm_file[0])) {
      printf("\nEnd of file reading %s\n", PDM_FILE_NAME_A);
      exit(0);
    }
    if (32 != fread (pdm_chunk[1], 1, 32, (FILE *)pdm_file[1])) {
      printf("\nEnd of file reading %s\n", PDM_FILE_NAME_A);
      exit(0);
    }
    pdm_word_count += 1;

    if((pdm_word_count & 0xfff) == 0) printf("Simulation progress: %d%%\r",  (pdm_word_count * 100) / (sz /32));

    unsigned pdm_word[2] = {0, 0};
    for (unsigned p=0;p<2;p++){
      for(unsigned i=0;i<32;i++){
        pdm_word[p] |= pdm_chunk[p][i] ? 0x1 << i : 0;
        //printf("%d", pdm_chunk[i]);
      }
      //printf("\n");
    }
      
    //ZIP 2 PDMS into SINGLE STREAM for mic_dual
    unsigned long long tmp64 = zip(pdm_word[0], pdm_word[1], 0);

    unsigned port_b = tmp64 >> 32;
    unsigned port_a = tmp64;
    //printbinln(port_a);
    //printbinln(port_b);

    outuint(c_mic_dual_pdm, port_a);
    outuint(c_mic_dual_pdm, port_b);


    //Now build word for mic_array
    //We could do this quicker with zip but this works
    for(unsigned i=0;i<8;i++){
      unsigned port_val = 0;
      for(unsigned j=0;j<4;j++){
        unsigned pdm_idx = 4 * i + j;
        port_val |= pdm_chunk[0][pdm_idx] ? 0x1 << (8 * j) : 0x0;
        port_val |= pdm_chunk[1][pdm_idx] ? 0x2 << (8 * j) : 0x0;
      }
      c_mic_array_pdm <: port_val;
    }
  }
}


int mic_array_data[MIC_DECIMATORS*MIC_CHANNELS][THIRD_STAGE_COEFS_PER_STAGE*MIC_DECIMATION_FACTOR];

void collect_output_std( streaming chanend c_ds_output[1]){
  unsafe{
  FILE * unsafe pcm_file[2];
  pcm_file[0] = fopen ( PCM_FILE_NAME_STD_A, "wb" );
  pcm_file[1] = fopen ( PCM_FILE_NAME_STD_B , "wb" );

  if ((pcm_file[0]==NULL)) {
      printf("file cannot be opened (%s)\n", PCM_FILE_NAME_STD_A);
      exit(1);
  }
  if ((pcm_file[1]==NULL)) {
      printf("file cannot be opened (%s)\n", PCM_FILE_NAME_STD_B);
      exit(1);
  }

  unsigned buffer;
  mic_array_frame_time_domain audio_frame[MIC_FRAME_BUFFERS];
  memset(mic_array_data, 0, MIC_DECIMATORS*MIC_CHANNELS*THIRD_STAGE_COEFS_PER_STAGE*MIC_DECIMATION_FACTOR*sizeof(int));

  mic_array_decimator_conf_common_t decimator_common_config = {
      MIC_DUAL_FRAME_SIZE,
      1,
      0,
      0,
      MIC_DECIMATION_FACTOR,
      g_third_stage_div_6_fir,
      0,
      FIR_COMPENSATOR_DIV_6,
      DECIMATOR_NO_FRAME_OVERLAP,
      MIC_FRAME_BUFFERS
  };

  mic_array_decimator_config_t decimator_config[MIC_DECIMATORS] = {
      {
          &decimator_common_config,
          mic_array_data[0],     // The storage area for the output decimator
          {INT_MAX, INT_MAX, INT_MAX, INT_MAX},  // Microphone gain compensation (turned off)
          MIC_CHANNELS,
          0 // Async interface disabled
      }
  };

  mic_array_decimator_configure(c_ds_output, MIC_DECIMATORS, decimator_config);
  mic_array_init_time_domain_frame(c_ds_output, MIC_DECIMATORS, buffer, audio_frame, decimator_config);

  while(1){
    // Get lib_mic_array
    mic_array_frame_time_domain * current_frame;
    current_frame = mic_array_get_next_time_domain_frame(c_ds_output, MIC_DECIMATORS, buffer, audio_frame, decimator_config);
    // printf("mic_array\n");  

    for(unsigned i=0;i<MIC_DUAL_FRAME_SIZE;i++)unsafe{
      int ch0 = current_frame->data[0][i];
      int ch1 = current_frame->data[1][i];

      // printf("ch0: %d\t ch1: %d\n", ch0, ch1);
      fwrite(&ch0, sizeof(ch0), 1, (FILE *)pcm_file[0]);
      fwrite(&ch1, sizeof(ch1), 1, (FILE *)pcm_file[1]);
    } 
  }
}
}//unsafe

void collect_output_dual(streaming chanend c_ds_output_dual[1]){
  unsafe{
  FILE * unsafe pcm_file[2];
  pcm_file[0] = fopen ( PCM_FILE_NAME_DUAL_A , "wb" );
  pcm_file[1] = fopen ( PCM_FILE_NAME_DUAL_B , "wb" );

  if ((pcm_file[0]==NULL)) {
      printf("file cannot be opened (%s)\n", PCM_FILE_NAME_DUAL_A);
      exit(1);
  }
  if ((pcm_file[1]==NULL)) {
      printf("file cannot be opened (%s)\n", PCM_FILE_NAME_DUAL_B);
      exit(1);
  }

  // No init for mic_dual


  while(1){
    // Get mic_dual
    unsigned addr = 0;
    c_ds_output_dual[0] :> addr;
    // printf("mic_dual\n");  

    for(unsigned i=0;i<MIC_DUAL_FRAME_SIZE;i++)unsafe{
      int ch0 = *((int *)addr + (4 * i) + 0);
      int ch1 = *((int *)addr + (4 * i) + 1);

      // printf("ch0: %d\t ch1: %d\n", ch0, ch1);
      fwrite(&ch0, sizeof(ch0), 1, (FILE *)pcm_file[0]);
      fwrite(&ch1, sizeof(ch1), 1, (FILE *)pcm_file[1]);
    } 
  }
}
}//unsafe

void ref_audio(streaming chanend c_ref_audio[]){
  while(1){
    for(unsigned i=0;i<2;i++) c_ref_audio[i] :> int _;
    for(unsigned i=0;i<2;i++) c_ref_audio[i] <: 0;
  }
}

void test2ch(){

    //mic_dual plumbing
    chan c_mic_dual_pdm; //This uses primatives rather than XC operators so has normal chan
    streaming chan c_ds_output_dual[1],  c_ref_audio[2];

    //mic_array plumbing
    streaming chan c_mic_array_pdm;
    streaming chan c_ds_output[1], c_4x_pdm_mic_0;

    par {
        get_pdm_from_file(c_mic_dual_pdm, c_mic_array_pdm);

        //mic_dual
        ref_audio(c_ref_audio);
        call_mic_dual_pdm_rx_decimate(c_mic_dual_pdm, c_ds_output_dual, c_ref_audio);
        collect_output_dual(c_ds_output_dual);


        //standard lib_mic_array
        pdm_rx_debug(c_mic_array_pdm, c_4x_pdm_mic_0, null);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        collect_output_std(c_ds_output);


    }
}

int main(){

    test2ch();
    return 0;
}
