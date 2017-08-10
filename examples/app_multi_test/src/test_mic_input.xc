// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <xs2_su_registers.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>
#include "stdio.h"
#include <stdlib.h>
#include <math.h>

#include <dsp.h>
#include "test_mic_input.h"
#include "mic_array.h"
#include "mic_array_board_support.h"
#include "median.h"


//If the decimation factor is changed the the coefs array of decimator_config must also be changed.
#define DECIMATION_FACTOR   2   //Corresponds to a 48kHz output sample rate
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define FRAME_BUFFER_COUNT  2   //The minimum of 2 will suffice for this example

#define COUNT 16

#define FRAME_LENGTH (1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2)
#define FFT_SINE_LUT dsp_sine_1024
#define FFT_CHANNELS (4)

typedef struct fd_frame {
    dsp_complex_t data[FFT_CHANNELS*2][FRAME_LENGTH/2];
} fd_frame;

static void test(streaming chanend c_ds_output0[DECIMATOR_COUNT],
                 streaming chanend c_ds_output1[DECIMATOR_COUNT],
                 chanend results) {
    uint64_t subband_rms_power[COUNT][FRAME_LENGTH/2];

    int data[16][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];
    
    unsafe{
        unsigned buffer0;
        unsigned buffer1;
        memset(data, 0, sizeof(data));

        mic_array_frame_fft_preprocessed audio0[FRAME_BUFFER_COUNT];
        mic_array_frame_fft_preprocessed audio1[FRAME_BUFFER_COUNT];

        mic_array_decimator_conf_common_t dcc0 = {
            MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
            1, //dc removal
            1, //bit reversed indexing
            0,
            DECIMATION_FACTOR,
            g_third_stage_div_2_fir,
            0,
            FIR_COMPENSATOR_DIV_2,
            DECIMATOR_NO_FRAME_OVERLAP,
            FRAME_BUFFER_COUNT};
        mic_array_decimator_conf_common_t dcc1 = {
            MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
            1, //dc removal
            1, //bit reversed indexing
            0,
            DECIMATION_FACTOR,
            g_third_stage_div_2_fir,
            0,
            FIR_COMPENSATOR_DIV_2,
            DECIMATOR_NO_FRAME_OVERLAP,
            FRAME_BUFFER_COUNT};
        mic_array_decimator_config_t dc0[2] = {
            {&dcc0, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
            {&dcc0, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };
        mic_array_decimator_config_t dc1[2] = {
            {&dcc1, data[8], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
            {&dcc1, data[12], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        mic_array_decimator_configure(c_ds_output0, DECIMATOR_COUNT, dc0);
        mic_array_init_frequency_domain_frame(c_ds_output0, DECIMATOR_COUNT, buffer0, audio0, dc0);
        mic_array_decimator_configure(c_ds_output1, DECIMATOR_COUNT, dc1);
        mic_array_init_frequency_domain_frame(c_ds_output1, DECIMATOR_COUNT, buffer1, audio1, dc1);

        for(unsigned i=0;i<128;i++) {
            mic_array_get_next_frequency_domain_frame(c_ds_output0, DECIMATOR_COUNT, buffer0, audio0, dc0);
            mic_array_get_next_frequency_domain_frame(c_ds_output1, DECIMATOR_COUNT, buffer1, audio1, dc1);
        }

#define R (6  + MIC_ARRAY_MAX_FRAME_SIZE_LOG2 - 8)
#define REPS (1<<R)


        memset(subband_rms_power, 0, sizeof(subband_rms_power));

        for(unsigned r=0;r<REPS;r++){
            for(int even = 0; even < 2; even++) {
                mic_array_frame_fft_preprocessed *  current;
                if (even) {
                    current = mic_array_get_next_frequency_domain_frame(c_ds_output0, DECIMATOR_COUNT, buffer0, audio0, dc0);
                } else {
                    current = mic_array_get_next_frequency_domain_frame(c_ds_output1, DECIMATOR_COUNT, buffer1, audio1, dc1);
                }

                for(unsigned i=0;i<FFT_CHANNELS;i++){
                    dsp_fft_forward(current->data[i], FRAME_LENGTH, FFT_SINE_LUT);
                    dsp_fft_split_spectrum(current->data[i], FRAME_LENGTH);
                }

                mic_array_frame_frequency_domain * fd_frame = (mic_array_frame_frequency_domain*)current;
                
                for(unsigned ch=0;ch<8;ch++){
                    for (unsigned band=1;band < FRAME_LENGTH/2;band++){
                        uint64_t power =
                            fd_frame->data[ch][band].re * (int64_t)fd_frame->data[ch][band].re +
                            fd_frame->data[ch][band].im * (int64_t)fd_frame->data[ch][band].im;
                        power >>= R;
                        subband_rms_power[ch+even*8][band] += power;
                    }
                }
            }
        }

#define DEBUG 0
#if DEBUG
        for (unsigned band=1;band < FRAME_LENGTH/2;band++){

            unsigned ch_a = 0;
            uint64_t a = subband_rms_power[ch_a][band];
            printf("%d %lld ", band, a);
            for(unsigned ch_b=1;ch_b<COUNT;ch_b++){
                uint64_t b = subband_rms_power[ch_b][band];

                printf("%ulld ", b);
            }
            printf("\n");
        }
#endif

        unsigned within_spec_count[COUNT];
        struct channels sort[COUNT];
        
        memset(within_spec_count, 0, sizeof(within_spec_count));

        for (unsigned band=1;band < FRAME_LENGTH/2;band++){
            uint64_t avg = 0;
            for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
                avg += subband_rms_power[ch_a][band] / COUNT;
                sort[ch_a].power = subband_rms_power[ch_a][band];
                sort[ch_a].chan_number = ch_a;
            }
            int ch_ref = find_median(sort, COUNT, avg);
//            printf("Band %d ref %d\n", band, ch_ref);
            uint64_t ref = subband_rms_power[ch_ref][band];
            
            for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
                uint64_t a = subband_rms_power[ch_a][band];
                //check that they are within 3db of ref
                unsigned v = a/2 < ref && ref/2 < a;
                within_spec_count[ch_a] += v;
            }
        }

        for(unsigned ch_a=0;ch_a<COUNT;ch_a++){
            results <: within_spec_count[ch_a];
        }
    }
}

void test_pdm(in buffered port:32 p_pdm0, out port p_clk0, clock pdmclk0,
              in buffered port:32 p_pdm1, out port p_clk1, clock pdmclk1,
              chanend results) {

    stop_clock(pdmclk0);
    stop_clock(pdmclk1);
    
    configure_clock_rate(pdmclk0, 100, 32);
    configure_port_clock_output(p_clk0, pdmclk0);
    configure_in_port(p_pdm0, pdmclk0);
    set_port_pull_down(p_pdm0);
    
    configure_clock_rate(pdmclk1, 100, 32);
    configure_port_clock_output(p_clk1, pdmclk1);
    configure_in_port(p_pdm1, pdmclk1);
    set_port_pull_down(p_pdm1);    
    
    start_clock(pdmclk0);
    start_clock(pdmclk1);

    streaming chan c_4x_pdm_mic0[DECIMATOR_COUNT];
    streaming chan c_ds_output0[DECIMATOR_COUNT];
    streaming chan c_4x_pdm_mic1[DECIMATOR_COUNT];
    streaming chan c_ds_output1[DECIMATOR_COUNT];

    par {
        mic_array_pdm_rx(p_pdm0, c_4x_pdm_mic0[0], c_4x_pdm_mic0[1]);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic0[0], c_ds_output0[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic0[1], c_ds_output0[1], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_pdm_rx(p_pdm1, c_4x_pdm_mic1[0], c_4x_pdm_mic1[1]);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic1[0], c_ds_output1[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic1[1], c_ds_output1[1], MIC_ARRAY_NO_INTERNAL_CHANS);
        test(c_ds_output0, c_ds_output1, results);
    }
}
