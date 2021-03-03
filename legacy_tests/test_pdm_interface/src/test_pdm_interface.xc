// Copyright (c) 2016-2021, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>

extern void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

void test8ch(){

    streaming chan c, d, c_port;
    par {
        pdm_rx_debug(c_port, c, d);
        {
            for(unsigned ch=0;ch<8;ch++){
                for(unsigned i=0;i<12;i++) c_port <: 0x00000000;

                unsigned mask = 1<<ch;

                c_port <: mask<<0;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: mask<<8;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: mask<<16;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: mask<<24;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<0;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<8;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<16;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<24;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;
            }
        }
        {
            unsigned ch_to_mic[8] = {0, 2, 4, 6, 1, 3, 5, 7};

            for(unsigned ch=0;ch<8;ch++){

                int min_sat; //first get the full -ve scale response
                int vals[8];

                for(unsigned i=0;i<4;i++){
                    c :> vals[i*2];
                    d :> vals[i*2+1];
                }

                for(unsigned j=0;j<5;j++){
                    for(unsigned i=0;i<4;i++){
                        int v;
                        c :> v;
                        if (v!= vals[i*2])
                            printf("Error: channels are not the same\n");
                        d :> v;
                        if (v!= vals[i*2+1])
                            printf("Error: channels are not the same\n");
                    }
                }
                unsigned m = ch_to_mic[ch];
                min_sat = vals[m];
                //then test each channel

               for(unsigned o=0;o<8;o++){
                   for(unsigned s=0;s<6;s++){
                       for(unsigned i=0;i<4;i++){
                           c :> vals[i*2];
                           d :> vals[i*2+1];
                       }
                       for(unsigned i=0;i<8;i++){
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
    }
}
void test4ch(){

    streaming chan c,  c_port;
    par {
        pdm_rx_debug(c_port, c, null);
        {
            for(unsigned ch=0;ch<8;ch++){
                for(unsigned i=0;i<12;i++) c_port <: 0x00000000;

                unsigned mask = 1<<ch;

                c_port <: mask<<0;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: mask<<8;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: mask<<16;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: mask<<24;
                c_port <: 0x00000000;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<0;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<8;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<16;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

                c_port <: 0x00000000;
                c_port <: mask<<24;
                for(unsigned i=0;i<10;i++) c_port <: 0x00000000;
            }
        }
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
    }
}

int main(){

#if CHANNELS == 4
    test4ch();
#else
    test8ch();
#endif
    return 0;
}
