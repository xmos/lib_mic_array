// Copyright (c) 2015-2019, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include <string.h>

#include "mic_array.h"

on tile[0]: out port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

#define DECIMATION_FACTOR   6   //Corresponds to a 16kHz output sample rate
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define FRAME_BUFFER_COUNT  2   //The minimum of 2 will suffice for this example

#define DECIMATOR_CH_COUNT 4    //Just to be clear

int data[DECIMATOR_COUNT*DECIMATOR_CH_COUNT]
         [THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

void example(streaming chanend c_ds_output[DECIMATOR_COUNT]) {
    unsafe{
        mic_array_frame_time_domain audio[FRAME_BUFFER_COUNT];

        unsigned buffer;    //No need to initialize this.
        memset(data, 0, DECIMATOR_COUNT*DECIMATOR_CH_COUNT*
                THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR*sizeof(int));

        mic_array_decimator_conf_common_t dcc = {
                0, // Frame size log 2 is set to 0, i.e. one sample per channel will be present in each frame
                1, // DC offset elimination is turned on
                0, // Index bit reversal is off
                0, // No windowing function is being applied
                DECIMATION_FACTOR,// The decimation factor is set to 6
                g_third_stage_div_6_fir, // This corresponds to a 16kHz output hence this coef array is used
                0, // Gain compensation is turned off
                FIR_COMPENSATOR_DIV_6, // FIR compensation is set to the corresponding coefficients
                DECIMATOR_NO_FRAME_OVERLAP, // Frame overlapping is turned off
                FRAME_BUFFER_COUNT  // The number of buffers in the audio array
        };

        mic_array_decimator_config_t dc[DECIMATOR_COUNT] = {
            {
                    &dcc,
                    data[0],     // The storage area for the output decimator
                    {INT_MAX, INT_MAX, INT_MAX, INT_MAX},  // Microphone gain compensation (turned off)
                    4,           // Enabled channel count (currently must be 4)
                    0,           // Disable async interface
            },
            {
                    &dcc,
                    data[4],     // The storage area for the output decimator
                    {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, // Microphone gain compensation (turned off)
                    4,           // Enabled channel count (currently must be 4)
                    0,           // Disable async interface
            }
        };
        mic_array_decimator_configure(c_ds_output, DECIMATOR_COUNT, dc);

        mic_array_init_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        while(1){
            mic_array_frame_time_domain *  current =
                                mic_array_get_next_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        }
    }
}

int main(){
    par{
        on tile[0]:{
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_pdm_to_dec[DECIMATOR_COUNT];
            streaming chan c_ds_output[DECIMATOR_COUNT];

            par{
                mic_array_pdm_rx(p_pdm_mics, c_pdm_to_dec[0], c_pdm_to_dec[1]);
                mic_array_decimate_to_pcm_4ch(c_pdm_to_dec[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
                mic_array_decimate_to_pcm_4ch(c_pdm_to_dec[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
                example(c_ds_output);
            }
        }
    }
    return 0;
}
