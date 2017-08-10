#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#include "mic_array_board_support.h"
#include "i2c.h"
#include "i2s_producer.h"
#include "test_mic_input.h"

port p_i2c                          = on tile[1]: XS1_PORT_4A; // Bit 0: SCLK, Bit 1: SDA
port p_rst_shared                   = on tile[1]: XS1_PORT_4B; // Bit 0: DAC_RST_N, Bit 1: ETH_RST_N

on tile[0]: out port p_clk0a             = XS1_PORT_1L;
on tile[0]: in buffered port:32 p_pdm0a  = XS1_PORT_8D;
on tile[0]: clock pdmclk0a               = XS1_CLKBLK_1;
on tile[0]: out port p_clk0b             = XS1_PORT_1F;
on tile[0]: in buffered port:32 p_pdm0b  = XS1_PORT_8B;
on tile[0]: clock pdmclk0b               = XS1_CLKBLK_2;
on tile[1]: out port p_clk1a             = XS1_PORT_1L;
on tile[1]: in buffered port:32 p_pdm1a  = XS1_PORT_8D;
on tile[1]: clock pdmclk1a               = XS1_CLKBLK_1;
on tile[1]: out port p_clk1b             = XS1_PORT_1F;
on tile[1]: in buffered port:32 p_pdm1b  = XS1_PORT_8B;
on tile[1]: clock pdmclk1b               = XS1_CLKBLK_2;

#define NSYNC 2

static void delay_me() {
    timer tmr;
    int t0;
    tmr :> t0;
    tmr when timerafter(t0 + 10000000) :> void;
}

#define COUNT 16

void receive(unsigned within_spec_count[COUNT], chanend results) {
    for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
        results :> within_spec_count[ch_a];
    }
}

void collator(chanend a, chanend b) {
    unsigned within_spec_count[2][COUNT];
    receive(within_spec_count[0], a);
    receive(within_spec_count[1], b);
    for(int z = 0; z < 2; z++) {
        for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
            unsigned mic_sum = 0;
            printf(" %4d",  within_spec_count[z][ch_a]);
            mic_sum += within_spec_count[z][ch_a];
            if(mic_sum > 256) {
                printf("  Mic %d: pass\n", ch_a);
            } else {
                printf("  Mic %d: fail\n", ch_a);
            }
        }
    }
}

int main(void) {
    chan a, b;
    i2c_master_if i_i2c[1];
    chan c_sync[NSYNC];
    par {
        on tile[1]: {
            int realhw = 0;
            if (realhw) {
                par {
                    i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
                    {
                        p_rst_shared <: 0x00;
                        mabs_init_pll(i_i2c[0], SMART_MIC_BASE);
                        delay_me();

                        i2c_regop_res_t res;
                        int i = 0x4A;
                        p_rst_shared <: 0xF;
            
                        uint8_t data = 1;
                        res = i_i2c[0].write_reg(i, 0x02, data); // Power down

                        data = 0x08;
                        res = i_i2c[0].write_reg(i, 0x04, data); // Slave, I2S mode, up to 24-bit

                        data = 0;
                        res = i_i2c[0].write_reg(i, 0x03, data); // Disable Auto mode and MCLKDIV2

                        data = 0x00;
                        res = i_i2c[0].write_reg(i, 0x09, data); // Disable DSP

                        data = 0;
                        res = i_i2c[0].write_reg(i, 0x02, data); // Power up
                    }
                }
            }
            for(int i = 0; i < NSYNC; i++) {
                c_sync[i] <: 1;
            }
            if (realhw) {
                i2s_tile();
            }
        }
        on tile[0]: collator(a, b);
        on tile[0]: {
            c_sync[0] :> int _;
            delay_me();
            test_pdm(p_pdm0a, p_clk0a, pdmclk0a,
                     p_pdm0b, p_clk0b, pdmclk0b, a);
        }
        on tile[1]: {
            c_sync[1] :> int _;
            delay_me();
            test_pdm(p_pdm1a, p_clk1a, pdmclk1a,
                     p_pdm1b, p_clk1b, pdmclk1b, b);
        }
    }
    return 0;
}
