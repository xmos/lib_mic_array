// Copyright (c) 2015, XMOS Ltd, All rights reserved

#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>
#include "mic_array.h"

#define MAX_DF 8

int data_0[4*COEFS_PER_PHASE*MAX_DF] = {0};
int data_1[4*COEFS_PER_PHASE*MAX_DF] = {0};
frame_audio audio[2];

{unsigned, unsigned} make_mask(unsigned a,unsigned b,
        unsigned c,unsigned d,
        unsigned e,unsigned f,
        unsigned h,unsigned g){
    unsigned r = a + (b<<8) + (c<<16) + (d<<24);
    unsigned s = e + (f<<8) + (g<<16) + (h<<24);
    return {r, s};
}


typedef struct {
  unsigned in_data[2];
  unsigned expected[8];
} test_t;

void test_crosstalk(streaming chanend c_pcm_0,
        streaming chanend c_pcm_1, streaming chanend c){

    unsigned buffer;
    unsigned frame_size_log2 = 0;

#define T (18*4)
    test_t tests[T] = {

            {{0x20202020, 0x20202020}, {0, 0, 0, 0, 0, 0, 0, 0}},
            {{0x21202020, 0x20202020}, {0, 0, 0, 1, 0, 0, 0, 0}},
            {{0x20212020, 0x20202020}, {0, 0, 1, 0, 0, 0, 0, 0}},
            {{0x20202120, 0x20202020}, {0, 1, 0, 0, 0, 0, 0, 0}},
            {{0x20202021, 0x20202020}, {1, 0, 0, 0, 0, 0, 0, 0}},
            {{0x20202020, 0x21202020}, {0, 0, 0, 0, 0, 0, 0, 1}},
            {{0x20202020, 0x20212020}, {0, 0, 0, 0, 0, 0, 1, 0}},
            {{0x20202020, 0x20202120}, {0, 0, 0, 0, 0, 1, 0, 0}},
            {{0x20202020, 0x20202021}, {0, 0, 0, 0, 1, 0, 0, 0}},
            {{0x21212121, 0x21212121}, {1, 1, 1, 1, 1, 1, 1, 1}},
            {{0x20212121, 0x21212121}, {1, 1, 1, 0, 1, 1, 1, 1}},
            {{0x21202121, 0x21212121}, {1, 1, 0, 1, 1, 1, 1, 1}},
            {{0x21212021, 0x21212121}, {1, 0, 1, 1, 1, 1, 1, 1}},
            {{0x21212120, 0x21212121}, {0, 1, 1, 1, 1, 1, 1, 1}},
            {{0x21212121, 0x20212121}, {1, 1, 1, 1, 1, 1, 1, 0}},
            {{0x21212121, 0x21202121}, {1, 1, 1, 1, 1, 1, 0, 1}},
            {{0x21212121, 0x21212021}, {1, 1, 1, 1, 1, 0, 1, 1}},
            {{0x21212121, 0x21212120}, {1, 1, 1, 1, 0, 1, 1, 1}},

            {{0x20202020, 0x20202020}, {0, 0, 0, 0, 0, 0, 0, 0}},
            {{0x40202020, 0x20202020}, {0, 0, 0, 1, 0, 0, 0, 0}},
            {{0x20402020, 0x20202020}, {0, 0, 1, 0, 0, 0, 0, 0}},
            {{0x20204020, 0x20202020}, {0, 1, 0, 0, 0, 0, 0, 0}},
            {{0x20202040, 0x20202020}, {1, 0, 0, 0, 0, 0, 0, 0}},
            {{0x20202020, 0x40202020}, {0, 0, 0, 0, 0, 0, 0, 1}},
            {{0x20202020, 0x20402020}, {0, 0, 0, 0, 0, 0, 1, 0}},
            {{0x20202020, 0x20204020}, {0, 0, 0, 0, 0, 1, 0, 0}},
            {{0x20202020, 0x20202040}, {0, 0, 0, 0, 1, 0, 0, 0}},
            {{0x40404040, 0x40404040}, {1, 1, 1, 1, 1, 1, 1, 1}},
            {{0x20404040, 0x40404040}, {1, 1, 1, 0, 1, 1, 1, 1}},
            {{0x40204040, 0x40404040}, {1, 1, 0, 1, 1, 1, 1, 1}},
            {{0x40402040, 0x40404040}, {1, 0, 1, 1, 1, 1, 1, 1}},
            {{0x40404020, 0x40404040}, {0, 1, 1, 1, 1, 1, 1, 1}},
            {{0x40404040, 0x20404040}, {1, 1, 1, 1, 1, 1, 1, 0}},
            {{0x40404040, 0x40204040}, {1, 1, 1, 1, 1, 1, 0, 1}},
            {{0x40404040, 0x40402040}, {1, 1, 1, 1, 1, 0, 1, 1}},
            {{0x40404040, 0x40404020}, {1, 1, 1, 1, 0, 1, 1, 1}},

            {{0x20202020, 0x20202020}, {0, 0, 0, 0, 0, 0, 0, 0}},
            {{0x1f202020, 0x20202020}, {0, 0, 0, 1, 0, 0, 0, 0}},
            {{0x201f2020, 0x20202020}, {0, 0, 1, 0, 0, 0, 0, 0}},
            {{0x20201f20, 0x20202020}, {0, 1, 0, 0, 0, 0, 0, 0}},
            {{0x2020201f, 0x20202020}, {1, 0, 0, 0, 0, 0, 0, 0}},
            {{0x20202020, 0x1f202020}, {0, 0, 0, 0, 0, 0, 0, 1}},
            {{0x20202020, 0x201f2020}, {0, 0, 0, 0, 0, 0, 1, 0}},
            {{0x20202020, 0x20201f20}, {0, 0, 0, 0, 0, 1, 0, 0}},
            {{0x20202020, 0x2020201f}, {0, 0, 0, 0, 1, 0, 0, 0}},
            {{0x1f1f1f1f, 0x1f1f1f1f}, {1, 1, 1, 1, 1, 1, 1, 1}},
            {{0x201f1f1f, 0x1f1f1f1f}, {1, 1, 1, 0, 1, 1, 1, 1}},
            {{0x1f201f1f, 0x1f1f1f1f}, {1, 1, 0, 1, 1, 1, 1, 1}},
            {{0x1f1f201f, 0x1f1f1f1f}, {1, 0, 1, 1, 1, 1, 1, 1}},
            {{0x1f1f1f20, 0x1f1f1f1f}, {0, 1, 1, 1, 1, 1, 1, 1}},
            {{0x1f1f1f1f, 0x201f1f1f}, {1, 1, 1, 1, 1, 1, 1, 0}},
            {{0x1f1f1f1f, 0x1f201f1f}, {1, 1, 1, 1, 1, 1, 0, 1}},
            {{0x1f1f1f1f, 0x1f1f201f}, {1, 1, 1, 1, 1, 0, 1, 1}},
            {{0x1f1f1f1f, 0x1f1f1f20}, {1, 1, 1, 1, 0, 1, 1, 1}},

            {{0x20202020, 0x20202020}, {0, 0, 0, 0, 0, 0, 0, 0}},
            {{0x00202020, 0x20202020}, {0, 0, 0, 1, 0, 0, 0, 0}},
            {{0x20002020, 0x20202020}, {0, 0, 1, 0, 0, 0, 0, 0}},
            {{0x20200020, 0x20202020}, {0, 1, 0, 0, 0, 0, 0, 0}},
            {{0x20202000, 0x20202020}, {1, 0, 0, 0, 0, 0, 0, 0}},
            {{0x20202020, 0x00202020}, {0, 0, 0, 0, 0, 0, 0, 1}},
            {{0x20202020, 0x20002020}, {0, 0, 0, 0, 0, 0, 1, 0}},
            {{0x20202020, 0x20200020}, {0, 0, 0, 0, 0, 1, 0, 0}},
            {{0x20202020, 0x20202000}, {0, 0, 0, 0, 1, 0, 0, 0}},
            {{0x00000000, 0x00000000}, {1, 1, 1, 1, 1, 1, 1, 1}},
            {{0x20000000, 0x00000000}, {1, 1, 1, 0, 1, 1, 1, 1}},
            {{0x00200000, 0x00000000}, {1, 1, 0, 1, 1, 1, 1, 1}},
            {{0x00002000, 0x00000000}, {1, 0, 1, 1, 1, 1, 1, 1}},
            {{0x00000020, 0x00000000}, {0, 1, 1, 1, 1, 1, 1, 1}},
            {{0x00000000, 0x20000000}, {1, 1, 1, 1, 1, 1, 1, 0}},
            {{0x00000000, 0x00200000}, {1, 1, 1, 1, 1, 1, 0, 1}},
            {{0x00000000, 0x00002000}, {1, 1, 1, 1, 1, 0, 1, 1}},
            {{0x00000000, 0x00000020}, {1, 1, 1, 1, 0, 1, 1, 1}},
    };

    for(unsigned test = 0; test<T;test++){


        c <: tests[test].in_data[0];
        c <: tests[test].in_data[1];


        for (unsigned df = 1; df <= 8; df++) {


            unsafe {
                decimator_config_common dcc = { frame_size_log2, 0, 0, 0, df,
                        fir_coefs[df], 0 };
                decimator_config dc0 = { &dcc, data_0, { INT_MAX, INT_MAX,
                        INT_MAX, INT_MAX } };
                decimator_config dc1 = { &dcc, data_1, { INT_MAX, INT_MAX,
                        INT_MAX, INT_MAX } };
                decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
            }

            decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio,
                    DECIMATOR_NO_FRAME_OVERLAP);
            for (unsigned i = 0; i < 4096; i++)
                decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
            frame_audio * current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1,
                    buffer, audio);


            for(unsigned i=0;i<8;i++){
                if((current->data[i][0] != 0) != tests[test].expected[i]){
                    printf("ERROR: crosstalk for: decimation factor %d and input %08x %08x\n",
                            df, tests[test].in_data[0], tests[test].in_data[1]);
                }
            }
        }
    }
    printf("SUCCESS\n");
    _Exit(1);
}

int main(){
    streaming chan c;
    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output_0, c_ds_output_1;
    par {
        {
            unsigned mask0 = 0;
            unsigned mask1 = 0;
            c:> mask0;
            c:> mask1;
            while(1){
                c_4x_pdm_mic_0 <: mask0;
                c_4x_pdm_mic_1 <: mask1;
                select {
                    case c:> mask0: c:> mask1;break;

                    default: break;
                }
            }
        }
        decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
        decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
        test_crosstalk(c_ds_output_0, c_ds_output_1, c);
    }
    return 0;
}
