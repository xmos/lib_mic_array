// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved

#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include "i2c.h"
#include "i2s.h"
#include "sines.h"

on tile[0]: in port p_mclk                  = XS1_PORT_1G;

//Ports for the DAC and clocking
out buffered port:32 p_i2s_dout[1]  = on tile[1]: {XS1_PORT_1P};
in port p_mclk_in1                  = on tile[1]: XS1_PORT_1O;
out buffered port:32 p_bclk         = on tile[1]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[1]: XS1_PORT_1N;
clock mclk                          = on tile[1]: XS1_CLKBLK_3;
clock bclk                          = on tile[1]: XS1_CLKBLK_4;

//The number of bins in the FFT (defined in this case by
// MIC_ARRAY_MAX_FRAME_SIZE_LOG2 given in mic_array_conf.h)


#define MASTER_TO_PDM_CLOCK_DIVIDER 4
#define MASTER_CLOCK_FREQUENCY 24576000
#define PDM_CLOCK_FREQUENCY (MASTER_CLOCK_FREQUENCY/(2*MASTER_TO_PDM_CLOCK_DIVIDER))
#define OUTPUT_SAMPLE_RATE (PDM_CLOCK_FREQUENCY/(32*2))


[[distributable]] static void i2s_handler(server i2s_callback_if i2s) {
    unsigned sample_idx=0;

    while (1) {
        select {
            case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
                i2s_config.mode = I2S_MODE_I2S;
                i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/OUTPUT_SAMPLE_RATE)/64;
                break;

            case i2s.restart_check() -> i2s_restart_t restart:
                restart = I2S_NO_RESTART;
                break;

            case i2s.receive(size_t index, int32_t sample):
                break;

            case i2s.send(size_t index) -> int32_t sample:
                sample = samples[sample_idx];
                if(index == 1) {
                    sample_idx++;
                }
                if(sample_idx == NSAMPLES) {
                    sample_idx = 0;
                }
                break;
        }
    }
}


void i2s_tile() {
    i2s_callback_if i_i2s;
    
    configure_clock_src(mclk, p_mclk_in1);
    start_clock(mclk);
    par {
        i2s_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, bclk, mclk);
        [[distribute]] i2s_handler(i_i2s);
    }
}
