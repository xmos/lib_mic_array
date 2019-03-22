// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>

//Expects binary file with one byte per bit. Byte value is either 0 or 1
#define PDM_FILE_NAME_A "ch_a.pdm"
#define PDM_FILE_NAME_B "ch_b.pdm"

#define PCM_FILE_NAME_A "ch_a.raw"
#define PCM_FILE_NAME_B "ch_b.raw"


in buffered port:32 p_pdm_mics   = XS1_PORT_1A;
unsafe{
    buffered port:32 * unsafe p_ptr = (buffered port:32 * unsafe) &p_pdm_mics;
}

//This needs to be done here because c_ddr_frontend becomes a chanend rather than chan
//Note unusual casting of channel to a port. i.e. we output directly onto channel rather than port
unsafe{
    void call_mic_dual_pdm_rx_decimate(chanend c_pdm_input, streaming chanend c_ds_output[], streaming chanend c_ref_audio[]){
        p_ptr = ( buffered port:32 * unsafe ) &c_pdm_input;
        //printf("%p\n", *p_ptr);
        mic_dual_pdm_rx_decimate(*p_ptr, c_ds_output[0], c_ref_audio);
    }
}


void test_pdm(chanend c_pdm_input){
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

  unsigned pdm_word_count = 0;
  unsigned char pdm_chunk[2][32];
  while(1){
    if (32 != fread (pdm_chunk[0], 1, 32, (FILE *)pdm_file[0])) {
      printf("End of file reading %s\n", PDM_FILE_NAME_A);
      exit(0);
    }
    if (32 != fread (pdm_chunk[1], 1, 32, (FILE *)pdm_file[1])) {
      printf("End of file reading %s\n", PDM_FILE_NAME_A);
      exit(0);
    }
    pdm_word_count += 1;

    if((pdm_word_count & 0xffff) == 0) printf("Pdm word chunk: %d\n", pdm_word_count);

    unsigned pdm_word[2] = {0, 0};
    for (unsigned p=0;p<2;p++){
      for(unsigned i=0;i<32;i++){
        pdm_word[p] |= pdm_chunk[p][i] ? 0x1 << i : 0;
        //printf("%d", pdm_chunk[i]);
      }
      //printf("\n");
    }
      
    //ZIP 2 PDMS into SINGLE STREAM
    unsigned long long tmp64 = zip(pdm_word[0], pdm_word[1], 0);

    unsigned port_b = tmp64 >> 32;
    unsigned port_a = tmp64;
    //printbinln(port_a);
    //printbinln(port_b);

    outuint(c_pdm_input, port_a);
    outuint(c_pdm_input, port_b);
  }
}

void collect_output(streaming chanend c_ds_output[]){
  FILE * unsafe pcm_file[2];
  pcm_file[0] = fopen ( PCM_FILE_NAME_A , "wb" );
  pcm_file[1] = fopen ( PCM_FILE_NAME_B , "wb" );

  if ((pcm_file[0]==NULL)) {
      printf("file cannot be opened (%s)\n", PCM_FILE_NAME_A);
      exit(1);
  }
  if ((pcm_file[1]==NULL)) {
      printf("file cannot be opened (%s)\n", PCM_FILE_NAME_B);
      exit(1);
  }

  while(1){
    unsigned addr;
    c_ds_output[0] :> addr;
    //printf("c_ds_output %p\n", addr);
    for(unsigned i=0;i<240;i++)unsafe{
      int ch0 = *((int *)addr + (4 * i) + 0);
      int ch1 = *((int *)addr + (4 * i) + 1);
      //printf("ch0: %d\t ch1: %d\n", ch0, ch1);
      //printintln(ch0);
      fwrite(&ch0, sizeof(ch0), 1, (FILE *)pcm_file[0]);
      fwrite(&ch1, sizeof(ch1), 1, (FILE *)pcm_file[1]);
    } 
  }
}

void ref_audio(streaming chanend c_ref_audio[]){
  while(1){
    for(unsigned i=0;i<2;i++) c_ref_audio[i] :> int _;
    for(unsigned i=0;i<2;i++) c_ref_audio[i] <: 0;
  }
}

void test2ch(){

    chan c_pdm_input; //This uses primatives rather than XC operators so has normal chan
    streaming chan c_ds_output[1],  c_ref_audio[2];

    par {
        call_mic_dual_pdm_rx_decimate(c_pdm_input, c_ds_output, c_ref_audio);
        test_pdm(c_pdm_input);
        ref_audio(c_ref_audio);
        collect_output(c_ds_output);
#if 0
        {
            unsigned ch_to_mic[4] = {0, 1, 2, 3};

            for(unsigned ch=0;ch<4;ch++){

                int min_sat; //first get the full -ve scale response
                int vals[4];

                for(unsigned i=0;i<4;i++){
                    c :> vals[i];
                }

                for(unsigned j=0;j<5;j++){
                    for(unsigned i=0;i<4;i++){
                        int v;
                        c :> v;
                        if (v!= vals[i])
                            printf("Error: channels are not the same\n");
                    }
                }
                unsigned m = ch_to_mic[ch];
                min_sat = vals[m];
                //then test each channel

               for(unsigned o=0;o<8;o++){
                   for(unsigned s=0;s<6;s++){
                       for(unsigned i=0;i<4;i++)
                           c :> vals[i];
                       for(unsigned i=0;i<4;i++){
                           if(m == i){
                               unsigned index = (7-o + s*8);
                               int d =  (vals[i] - min_sat)/2 - fir1_debug[index];
                               if(d*d>1)
                                   printf("Error: unexpected coefficient\n");
                           } else {
                               if((vals[i] - min_sat) != 0)
                                   printf("Error: crosstalk detected\n");
                           }
                       }
                   }
                }
            }
            printf("Success!\n");
            _Exit(0);
        }
#endif
    }
}

int main(){

    test2ch();
    return 0;
}
