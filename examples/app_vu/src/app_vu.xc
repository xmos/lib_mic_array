// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include <string.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include "mic_array.h"
#include "mic_array_board_support.h"
#include "dsp.h"

#include "i2c.h"

//If the decimation factor is changed the the coefs array of decimator_config must also be changed.
#define DECIMATION_FACTOR   2   //Corresponds to a 48kHz output sample rate
#define DECIMATOR_COUNT     2   //8 channels requires 2 decimators
#define FRAME_BUFFER_COUNT  2   //The minimum of 2 will suffice for this example

on tile[1]:port p_i2c                       =  XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA

on tile[0]:mabs_led_ports_t leds = MIC_BOARD_SUPPORT_LED_PORTS;
on tile[0]:in port p_buttons =  MIC_BOARD_SUPPORT_BUTTON_PORTS;

on tile[0]: out port p_pdm_clk              = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

const int32_t filter_coeffs_A_weight[] = {
    125794161,  251588322,  125794161,  120558903,  -6768130,
    536870911,  -1073882321,  537011429,  1016763977,  -480585240,
    536870911,  -1073601322,  536730429,  1070850480,  -533983462,
};
const uint32_t num_sections_A_weight = 3;
const uint32_t q_format_A_weight = 29;
int32_t filter_state_A_weight[3*DSP_NUM_STATES_PER_BIQUAD] = {0};
const int32_t filter_coeffs_C_weight[] = {
    106216601,  212433202,  106216601,  120558903,  -6768130,
    536870911,  -1073741822,  536870911,  1070850480,  -533983461,
};
const uint32_t num_sections_C_weight = 2;
const uint32_t q_format_C_weight = 29;
int32_t filter_state_C_weight[2*DSP_NUM_STATES_PER_BIQUAD] = {0};

int data[8][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];


void update_power(uint32_t &lpf_p, uint32_t alpha, uint32_t p){
    int64_t l =  (int64_t)lpf_p *(int64_t)(UINT_MAX - alpha);
    int64_t r =  (int64_t)p *(int64_t)alpha;
    lpf_p = (l+r)>>32;
}

void vu(streaming chanend c_ds_output[DECIMATOR_COUNT],
        client interface mabs_led_button_if lb) {

    unsafe{
        unsigned buffer;
        memset(data, 0, sizeof(data));

        mic_array_frame_time_domain audio[FRAME_BUFFER_COUNT];

        mic_array_decimator_conf_common_t dcc = {0, 1, 0, 0, DECIMATION_FACTOR,
               g_third_stage_div_2_fir, 0, FIR_COMPENSATOR_DIV_2,
               DECIMATOR_NO_FRAME_OVERLAP, FRAME_BUFFER_COUNT};

        mic_array_decimator_config_t dc[2] = {
          {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
          {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };

        mic_array_decimator_configure(c_ds_output, DECIMATOR_COUNT, dc);
        mic_array_init_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        unsigned selected_ch = 0;

        uint32_t pZ_slow = 0, pZ_fast = 0;
        uint32_t pA_slow = 0, pA_fast = 0;
        uint32_t pC_slow = 0, pC_fast = 0;

        uint32_t alpha_slow = (int64_t)((double)UINT_MAX * 0.01);
        uint32_t alpha_fast = (int64_t)((double)UINT_MAX * 0.1);

        while(1){

            mic_array_frame_time_domain *  current =
                mic_array_get_next_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

            int32_t v = current->data[selected_ch][0];

            v = v >> 1; // To ensure the gain of the A weighting never overflows.

            int32_t a = dsp_filters_biquads(v, filter_coeffs_A_weight,
                    filter_state_A_weight, num_sections_A_weight, q_format_A_weight);
            int32_t c = dsp_filters_biquads(v, filter_coeffs_C_weight,
                    filter_state_C_weight, num_sections_C_weight, q_format_C_weight);

            uint32_t pV = ((int64_t)v * (int64_t)v)>>(31 - 1);
            update_power(pZ_slow, alpha_slow, pV);
            update_power(pZ_fast, alpha_fast, pV);

            uint32_t pA = ((int64_t)a * (int64_t)a)>>(31 - 1);
            update_power(pA_slow, alpha_slow, pA);
            update_power(pA_fast, alpha_fast, pA);

            uint32_t pC = ((int64_t)c * (int64_t)c)>>(31 - 1);
            update_power(pC_slow, alpha_slow, pC);
            update_power(pC_fast, alpha_fast, pC);

            printf("%12u %12u %12u %12u %12u %12u\n", pZ_slow, pZ_fast,
                    pA_slow, pA_fast, pC_slow, pC_fast);

        }
    }
}

#define MASTER_TO_PDM_CLOCK_DIVIDER 4

int main() {

    i2c_master_if i_i2c[1];
    par {

        on tile[1]:  [[distribute]]i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
        on tile[1]:  {
            mabs_init_pll(i_i2c[0], ETH_MIC_ARRAY);
        }
        on tile[0]: {
            configure_clock_src_divide(pdmclk, p_mclk, MASTER_TO_PDM_CLOCK_DIVIDER);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_4x_pdm_mic[DECIMATOR_COUNT];
            streaming chan c_ds_output[DECIMATOR_COUNT];

            interface mabs_led_button_if lb[1];

            par {
                mabs_button_and_led_server(lb, 1, leds, p_buttons);
                mic_array_pdm_rx(p_pdm_mics, c_4x_pdm_mic[0], c_4x_pdm_mic[1]);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
                vu(c_ds_output, lb[0]);
            }
        }
    }
    return 0;
}
