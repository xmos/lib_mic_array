// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
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

#include "log2_lut.h"

q8_24 uint32_log2(uint32_t r){
    unsigned c = clz(r);
    unsigned m = (r>>((32 - LOG2_BITS) - (c + 1)))&LOG2_MASK;
    return -(int32_t)((c<<24) + log2_lut[m]);
}

q8_24 uint64_log2(uint64_t r){
    unsigned c = clz(r>>32);
    if(c == 32){
        unsigned more_c = clz(r&0xffffffff);
        c+=more_c;
        uint64_t t = (r>>((32 - LOG2_BITS) - (more_c + 1)));
        unsigned m =t&LOG2_MASK;
        return -(int32_t)((c<<24) + log2_lut[m]);
    } else {
        uint64_t t =  (r>>((32 - LOG2_BITS) - (c + 1)));
        unsigned m =(t>>32)&LOG2_MASK;
        return -(int32_t)((c<<24) + log2_lut[m]);
    }
}

q8_24 log2_to_log10(const q8_24 i){
    const int32_t d = 1292913986; // (1.0/log2(10)) * (2^(31 + 1)-1)
    return ((int64_t)d * (int64_t)i)>>(31+1);
}

int64_t power(int32_t v){
    uint64_t p =  (int64_t)v*(int64_t)v;
    p<<=1;
    return p;
}

void update_power(uint64_t &lpf_p, uint32_t alpha, uint64_t p){

    uint64_t lpf_p_top = lpf_p >> 32;
    uint64_t lpf_p_bot = lpf_p&0xffffffff;

    uint64_t not_alpha = (uint64_t)(UINT_MAX - alpha);

    uint64_t l_top =  lpf_p_top * not_alpha;
    uint64_t l_bot =  lpf_p_bot * not_alpha;

    uint64_t l = l_top + (l_bot>>32);

    uint64_t p_top = p >> 32;
    uint64_t p_bot = p&0xffffffff;

    int64_t r_top =  p_top *(int64_t)alpha;
    int64_t r_bot =  p_bot *(int64_t)alpha;

    uint64_t r = r_top + (r_bot>>32);

    lpf_p = l+r;
}

/*
   AKU441
   116dbSPL = 0  dbFS = 2**32-1  linear power
    94dBSPL = -26dBFS = 10788470 linear power
    62dbSPL = -54dbFS = 6807     linear power
              -89dbFS = 5        linear power (noise floor, a weighted)

    Brand x
   130dbSPL = 0  dbFS = 2**32-1  linear power
    94dBSPL = -36dBFS = 1078847  linear power
             -105dbFS = 5        linear power (noise floor, a weighted)

*/
void vu(streaming chanend c_ds_output[DECIMATOR_COUNT],
        client interface mabs_led_button_if lb, chanend c_printer) {

    unsafe{
        unsigned buffer;
        memset(data, 0, sizeof(data));

        mic_array_frame_time_domain audio[FRAME_BUFFER_COUNT];

        mic_array_decimator_conf_common_t dcc = {0, 1, 0, 0, DECIMATION_FACTOR,
               g_third_stage_div_2_fir, 0, FIR_COMPENSATOR_DIV_2,
               DECIMATOR_NO_FRAME_OVERLAP, FRAME_BUFFER_COUNT};

        mic_array_decimator_config_t dc[2] = {
          {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0},
          {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0}
        };

        mic_array_decimator_configure(c_ds_output, DECIMATOR_COUNT, dc);
        mic_array_init_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        unsigned selected_ch = 0;

        uint64_t pZ_slow = 0, pZ_fast = 0;
        uint64_t pA_slow = 0, pA_fast = 0;
        uint64_t pC_slow = 0, pC_fast = 0;

        //TODO give these exponential decay rates meaning.
        uint32_t alpha_slow = (int64_t)((double)UINT_MAX * 0.01);
        uint32_t alpha_fast = (int64_t)((double)UINT_MAX * 0.1);

        unsigned sample_rate = 48000;
        unsigned counter = 0;
        while(1){

            mic_array_frame_time_domain *  current =
                mic_array_get_next_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

            int32_t v = current->data[selected_ch][0];

            v = v >> 1; // To ensure the gain of the A weighting never overflows,
                        // equlivant to -6.02dB.

            int32_t a = dsp_filters_biquads(v, filter_coeffs_A_weight,
                    filter_state_A_weight, num_sections_A_weight, q_format_A_weight);
            int32_t c = dsp_filters_biquads(v, filter_coeffs_C_weight,
                    filter_state_C_weight, num_sections_C_weight, q_format_C_weight);

            uint64_t pV = power(v);
            update_power(pZ_slow, alpha_slow, pV);
            update_power(pZ_fast, alpha_fast, pV);

            uint64_t pA = power(a);
            update_power(pA_slow, alpha_slow, pA);
            update_power(pA_fast, alpha_fast, pA);

            uint64_t pC = power(c);
            update_power(pC_slow, alpha_slow, pC);
            update_power(pC_fast, alpha_fast, pC);

            q8_24 dB_pZ_slow = log2_to_log10(uint64_log2(pZ_slow));
            dB_pZ_slow = dB_pZ_slow*10 + Q24(6.02); //+6.02dB to undo the above

            q8_24 dB_pZ_fast = log2_to_log10(uint64_log2(pZ_fast));
            dB_pZ_fast = dB_pZ_fast*10 + Q24(6.02);

            q8_24 dB_pA_slow = log2_to_log10(uint64_log2(pA_slow));
            dB_pA_slow = dB_pA_slow*10 + Q24(6.02);

            q8_24 dB_pA_fast = log2_to_log10(uint64_log2(pA_fast));
            dB_pA_fast = dB_pA_fast*10 + Q24(6.02);

            q8_24 dB_pC_slow = log2_to_log10(uint64_log2(pC_slow));
            dB_pC_slow = dB_pC_slow*10 + Q24(6.02);

            q8_24 dB_pC_fast = log2_to_log10(uint64_log2(pC_fast));
            dB_pC_fast = dB_pC_fast*10 + Q24(6.02);

            if(counter == (sample_rate/16)){
                master{
                    c_printer <: dB_pZ_slow;
                    c_printer <: dB_pZ_fast;
                    c_printer <: dB_pA_slow;
                    c_printer <: dB_pA_fast;
                    c_printer <: dB_pC_slow;
                    c_printer <: dB_pC_fast;
                }
                counter = 0;
            } else {
                counter++;
            }
        }
    }
}

void printer(chanend c_printer){
    q8_24 v[6];
    while(1){
        slave{
            for(unsigned i=0;i<6;i++){
                c_printer :> v[i];
            }
        }
        for(unsigned i=0;i<6;i++){
            printf("%f ", F24(v[i]));
//            xscope_float(i, F24(v[i]));
        }
        printf("\n");
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
            chan c_printer;
            par {
                mabs_button_and_led_server(lb, 1, leds, p_buttons);
                mic_array_pdm_rx(p_pdm_mics, c_4x_pdm_mic[0], c_4x_pdm_mic[1]);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
                mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
                vu(c_ds_output, lb[0], c_printer);
                printer(c_printer);
            }
        }
    }
    return 0;
}
