// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdint.h>

#include "mic_array.h"

#include "lib_dsp.h"

#define DF 2    //Decimation Factor

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

#define FFT_N (1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2)

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};

int your_favourite_window_function(unsigned i, unsigned window_length){
    return INT_MAX; //Boxcar
}

void freq_domain_example(streaming chanend c_ds_output[2]){

    unsigned buffer ;
    mic_array_frame_fft_preprocessed comp[3];

    int window[FFT_N/2];
    for(unsigned i=0;i<FFT_N/2;i++)
         window[i] = your_favourite_window_function(i, FFT_N);

    unsafe{
        mic_array_decimator_config_common dcc = {
                MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
                1,
                1,
                window,
                DF,
                g_third_stage_div_2_fir,
                0,
                FIR_COMPENSATOR_DIV_2,
                DECIMATOR_HALF_FRAME_OVERLAP,
                4
        };

        mic_array_decimator_config dc[2] = {
                {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        mic_array_decimator_configure(c_ds_output, 2, dc);

        mic_array_init_frequency_domain_frame(c_ds_output, 2, buffer, comp, dc);

        while(1){

           //Recieve the preprocessed frames ready for the FFT
            mic_array_frame_fft_preprocessed * current = mic_array_get_next_frequency_domain_frame(c_ds_output, 2, buffer, comp, dc);

           for(unsigned i=0;i<4;i++){
               //Apply one FFT to two channels at a time
               lib_dsp_fft_forward_complex((lib_dsp_fft_complex_t*)current->data[i], FFT_N, lib_dsp_sine_512);

               //Reconstruct the two independent frequency domain representations
               lib_dsp_fft_reorder_two_real_inputs((lib_dsp_fft_complex_t*)current->data[i], FFT_N);
           }

           //Now we can address the output as a frequency frame(i.e. 8 complex channels of length FFT_N/2)
           mic_array_frame_frequency_domain * frequency = (mic_array_frame_frequency_domain *)current;

           //Now to get back to the time domain
           unsigned channel = 0;
           lib_dsp_fft_complex_t p[FFT_N];  //No need to zero this
           for(unsigned i=0;i<FFT_N/2;i++){
               p[i].re =  frequency->data[channel][i].re;
               p[i].im =  frequency->data[channel][i].im;
           }
           lib_dsp_fft_rebuild_one_real_input(p, FFT_N);
           lib_dsp_fft_bit_reverse(p, FFT_N);
           lib_dsp_fft_inverse_complex(p, FFT_N, lib_dsp_sine_512);

           //Now the p array is a time domain representation of the selected channel.
           //   -The imaginary component will be zero(or very close)
           //   -The real component will be the time domain representation.

           //Time to recombine the time domain frame with a bit of overlap-and-add.

        }
    }
}

int main(){

    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output[2];

    configure_clock_src_divide(pdmclk, p_mclk, 4);
    configure_port_clock_output(p_pdm_clk, pdmclk);
    configure_in_port(p_pdm_mics, pdmclk);
    start_clock(pdmclk);

    par{
        mic_array_pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
        freq_domain_example(c_ds_output);
        par(int i=0;i<4;i++)while(1);
    }
    return 0;
}

