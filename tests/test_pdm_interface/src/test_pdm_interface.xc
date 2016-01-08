// Copyright (c) 2016, XMOS Ltd, All rights reserved

#include "mic_array.h"
#include <limits.h>
#include <stdio.h>
#include <xs1.h>
#include <xclib.h>
#include <math.h>
#include <stdlib.h>
#include <print.h>

extern void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);

int main(){
    streaming chan c, d, c_port;
    par {
        pdm_rx_debug(c_port, c, d);
        {
            //for(unsigned i=0;i<12;i++) c_port <: 0x00000000;

            c_port <: 0x000000ff;
            c_port <: 0x00000000;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

            c_port <: 0x0000ff00;
            c_port <: 0x00000000;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

            c_port <: 0x00ff0000;
            c_port <: 0x00000000;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

            c_port <: 0xff000000;
            c_port <: 0x00000000;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

            c_port <: 0x00000000;
            c_port <: 0x000000ff;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

            c_port <: 0x00000000;
            c_port <: 0x0000ff00;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

            c_port <: 0x00000000;
            c_port <: 0x00ff0000;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;

            c_port <: 0x00000000;
            c_port <: 0xff000000;
            for(unsigned i=0;i<10;i++) c_port <: 0x00000000;
        }
        {
           for(unsigned o=0;o<8;o++){
               for(unsigned s=0;s<6;s++){
                    int v, t;
                    c :> v;
                    d :> t;

                    if(t != v)
                        printf("Error: not all channels are the same\n");
                    for(unsigned i=0;i<3;i++){
                        c:> t;
                        if(t!= v)
                            printf("Error: not all channels are the same\n");
                        d:> t;
                        if(t!= v)
                            printf("Error: not all channels are the same\n");
                    }

                    unsigned index = (7-o + s*8);
                    int d =  (t + 1968382570)/2 - fir1_debug[index];
                    if(d*d>1)
                        printf("Error: coef incorrect, delta: %d\n", v - fir1_debug[index]);
               }
            }
            printf("Success!\n");
            _Exit(1);
        }
    }
    return 0;
}
