#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>

#include "mic_array.h"

on tile[0]: in port p_pdm_clk             = XS1_PORT_1E;
on tile[0]: in port p_pdm_mics            = XS1_PORT_8B;
on tile[0]: in port p_mclk                = XS1_PORT_1F;
on tile[0]: clock mclk                    = XS1_CLKBLK_1;
on tile[0]: clock pdmclk                  = XS1_CLKBLK_2;


// LEDs
out port p_led0to7              = on tile[0]: XS1_PORT_8C;
out port p_led8                 = on tile[0]: XS1_PORT_1K;
out port p_led9                 = on tile[0]: XS1_PORT_1L;
out port p_led10to12            = on tile[0]: XS1_PORT_8D;
out port p_leds_oen             = on tile[0]: XS1_PORT_1P;

void led_server(chanend c){
    p_leds_oen <: 1;
    p_leds_oen <: 0;

    int vled0to7= ~0;
    int vled8= ~0;
    int vled9= ~0;
    int vled10to12= ~0;

    while(1){
        select {
            case c:> int i:{
                switch(i){
                case 0:
                    vled10to12 = vled10to12&~(4);
                    break;
                case 1:
                    vled0to7 = vled0to7&~(3<<0);
                    break;
                case 2:
                    vled0to7 = vled0to7&~(3<<2);
                    break;
                case 3:
                    vled0to7 = vled0to7&~(3<<4);
                    break;
                case 4:
                    vled0to7 = vled0to7&~(3<<6);
                    break;
                case 5:
                    vled8 =0;
                    vled9 =0;
                    break;
                case 6:
                    vled10to12 = vled10to12&~(3);
                    break;
                case 7:
                    break;
                }
                break;
            }
        }
        p_led0to7<:vled0to7;
        p_led8<:vled8;
        p_led9<:vled9;
        p_led10to12<:vled10to12;

    }

}


void mic_check_12(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1, chanend c){

    unsigned buffer = 1;     //buffer index
    frame_audio audio[2];    //double buffered
    memset(audio, sizeof(frame_audio), 2);

    unsigned long long energy[8] = {0};
    int prev_val[8] = {0};
    int val[8] = {0};

    unsafe{
        c_ds_output_0 <: (frame_audio * unsafe)audio[0].data[0];
        c_ds_output_1 <: (frame_audio * unsafe)audio[0].data[2];

        unsigned count = 0;
        while(1){

            schkct(c_ds_output_0, 8);
            schkct(c_ds_output_1, 8);

            c_ds_output_0 <: (frame_audio * unsafe)audio[buffer].data[0];
            c_ds_output_1 <: (frame_audio * unsafe)audio[buffer].data[2];
            count++;
            buffer = 1 - buffer;


            prev_val[0] = val[0];
            val[0] = audio[buffer].data[0][0].ch_a; //mic 0
            prev_val[1] = val[1];
            val[1] = audio[buffer].data[0][0].ch_b; //mic 1
            prev_val[2] = val[2];
            val[2] = audio[buffer].data[1][0].ch_a; //mic 2
            prev_val[3] = val[3];
            val[3] = audio[buffer].data[1][0].ch_b; //mic 3
            prev_val[4] = val[4];
            val[4] = audio[buffer].data[2][0].ch_a; //mic 4
            prev_val[5] = val[5];
            val[5] = audio[buffer].data[2][0].ch_b; //mic 5
            prev_val[6] = val[6];
            val[6] = audio[buffer].data[3][0].ch_a; //mic 6
            prev_val[7] = val[7];
            val[7] = audio[buffer].data[3][0].ch_b; //mic 7 - not present

#define N 3
            for(unsigned i=0;i<8;i++){
                long long delta = val[i] - prev_val[i];
                delta >>= 2;
                energy[i] += (delta*delta);
                energy[i] =  energy[i] - (energy[i]>>N);
            }

             if(count == (24000)){
                for(unsigned i=0;i<8;i++){
                    if(energy[i] <= (1<<N)){
                        printf("* ");
                    } else {
                        printf("%d ", i);
                        c<:i;
                    }
                }
                printf("\n");
                count = 0;
             }


        }
    }
}

int main(){

    par{
        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;
            chan c;
            configure_clock_src(mclk, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk);
            start_clock(pdmclk);
            decimator_config dc = {0, 1, 0, 0};
            par{
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_0, c_ds_output_0, dc);
                decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_1, c_ds_output_1, dc);
                mic_check_12(c_ds_output_0, c_ds_output_1, c);
                led_server(c);
            }
        }
    }
    return 0;
}
