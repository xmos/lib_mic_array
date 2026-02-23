// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <platform.h>
#include <xcore/port.h>
#include <xcore/hwtimer.h>
#include <xcore/chanend.h>
#include <xcore/parallel.h>

#include "sw_pll.h"
#include "mic_array.h"
#include "app_config.h"

#define AUDIO_FRAME_LEN ( \
    MIC_ARRAY_CONFIG_MIC_IN_COUNT * MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME)

#define PROFILE_SECONDS (5)

DECLARE_JOB(mic_array_start, (chanend_t));
DECLARE_JOB(burn_mips, (void));
DECLARE_JOB(count_mips, (void));
DECLARE_JOB(print_mips, (const unsigned));

void eat_audio_frames_task(
    chanend_t c_from_decimator,
    const unsigned channel_count,
    const unsigned sample_count)
{

    static int32_t audio_frame[AUDIO_FRAME_LEN];

    hwtimer_t tmr = hwtimer_alloc();
    uint32_t time_now = hwtimer_get_time(tmr);
    uint32_t time_end = time_now + (PROFILE_SECONDS * XS1_TIMER_HZ);

    while (hwtimer_get_time(tmr) < time_end)
    {
        ma_frame_rx(
            audio_frame,
            c_from_decimator,
            channel_count,
            sample_count);
    }
    hwtimer_free(tmr);
}

#if USE_CUSTOM_FILTER

#include "custom_filter.h"

void init_mic_conf(
    mic_array_conf_t *mic_array_conf,
    mic_array_filter_conf_t filter_conf[NUM_DECIMATION_STAGES],
    unsigned *channel_map)
{
    static int32_t stg1_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][8];
    static int32_t stg2_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][CUSTOM_FILTER_STG2_TAP_COUNT];
    memset(mic_array_conf, 0, sizeof(mic_array_conf_t));

    // decimator
    mic_array_conf->decimator_conf.filter_conf = &filter_conf[0];
    mic_array_conf->decimator_conf.num_filter_stages = NUM_DECIMATION_STAGES;
    // stage 1
    filter_conf[0].coef = (int32_t *)custom_filter_stg1_coef;
    filter_conf[0].num_taps = CUSTOM_FILTER_STG1_TAP_COUNT;
    filter_conf[0].decimation_factor = CUSTOM_FILTER_STG1_DECIMATION_FACTOR;
    filter_conf[0].state = (int32_t *)stg1_filter_state;
    filter_conf[0].shr = CUSTOM_FILTER_STG1_SHR;
    filter_conf[0].state_words_per_channel = filter_conf[0].num_taps / 32;
    // stage 2
    filter_conf[1].coef = (int32_t *)custom_filter_stg2_coef;
    filter_conf[1].num_taps = CUSTOM_FILTER_STG2_TAP_COUNT;
    filter_conf[1].decimation_factor = CUSTOM_FILTER_STG2_DECIMATION_FACTOR;
    filter_conf[1].state = (int32_t *)stg2_filter_state;
    filter_conf[1].shr = CUSTOM_FILTER_STG2_SHR;
    filter_conf[1].state_words_per_channel = CUSTOM_FILTER_STG2_TAP_COUNT;
    // stage 3
#if (NUM_DECIMATION_STAGES == 3)
    static int32_t stg3_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][CUSTOM_FILTER_STG3_TAP_COUNT];
    filter_conf[2].coef = (int32_t *)custom_filter_stg3_coef;
    filter_conf[2].num_taps = CUSTOM_FILTER_STG3_TAP_COUNT;
    filter_conf[2].decimation_factor = CUSTOM_FILTER_STG3_DECIMATION_FACTOR;
    filter_conf[2].state = (int32_t *)stg3_filter_state;
    filter_conf[2].shr = CUSTOM_FILTER_STG3_SHR;
    filter_conf[2].state_words_per_channel = CUSTOM_FILTER_STG3_TAP_COUNT;
#else
#define CUSTOM_FILTER_STG3_DECIMATION_FACTOR (1) /*for PDM RX block size calculation below to work for both 2 and 3 stage filter*/
#endif
    // pdm rx
    static uint32_t pdmrx_out_block[MIC_ARRAY_CONFIG_MIC_COUNT][CUSTOM_FILTER_STG2_DECIMATION_FACTOR * CUSTOM_FILTER_STG3_DECIMATION_FACTOR];
    static uint32_t __attribute__((aligned(8))) pdmrx_out_block_double_buf[2][MIC_ARRAY_CONFIG_MIC_COUNT * CUSTOM_FILTER_STG2_DECIMATION_FACTOR * CUSTOM_FILTER_STG3_DECIMATION_FACTOR];
    mic_array_conf->pdmrx_conf.pdm_out_words_per_channel = CUSTOM_FILTER_STG2_DECIMATION_FACTOR * CUSTOM_FILTER_STG3_DECIMATION_FACTOR;
    mic_array_conf->pdmrx_conf.pdm_out_block = (uint32_t *)pdmrx_out_block;
    mic_array_conf->pdmrx_conf.pdm_in_double_buf = (uint32_t *)pdmrx_out_block_double_buf;
    mic_array_conf->pdmrx_conf.channel_map = channel_map;
}
#endif

void mic_array_initialise()
{
    // Set the pll to the required frequency for the mic array
    sw_pll_fixed_clock(APP_MCLK_FREQUENCY);

    // Set up the mic array resources
#if (MIC_ARRAY_CONFIG_MIC_COUNT == 2)
    pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
        PORT_MCLK_IN, PORT_PDM_CLK, PORT_PDM_DATA,
        APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, XS1_CLKBLK_1, XS1_CLKBLK_2);
#else
    pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(
        PORT_MCLK_IN, PORT_PDM_CLK, PORT_PDM_DATA,
        APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, XS1_CLKBLK_1);
#endif

    // Initialise the mic array
#if !USE_CUSTOM_FILTER
    mic_array_init(&pdm_res, NULL, APP_SAMP_FREQ);
#else
    mic_array_conf_t mic_array_conf;
    mic_array_filter_conf_t filter_conf[NUM_DECIMATION_STAGES];
    init_mic_conf(&mic_array_conf, filter_conf, NULL);
    mic_array_init_custom_filter(&pdm_res, &mic_array_conf);
#endif
}

int main_tile_0(chanend_t c_audio_frames)
{
    printf("Running " APP_NAME "..\n");
    eat_audio_frames_task(
        c_audio_frames,
        MIC_ARRAY_CONFIG_MIC_IN_COUNT,
        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);
    exit(0);  // exit to the host after profiling is done
    return 0; // should never reach here
}

int main_tile_1(chanend_t c_audio_frames)
{
    mic_array_initialise();
    PAR_JOBS(
        PJOB(mic_array_start, (c_audio_frames)),
        #if MIC_ARRAY_CONFIG_USE_PDM_ISR
        PJOB(burn_mips, ()),
        #endif
        PJOB(burn_mips, ()),
        PJOB(burn_mips, ()),
        PJOB(burn_mips, ()),
        PJOB(count_mips, ()),
        PJOB(print_mips, (MIC_ARRAY_CONFIG_USE_PDM_ISR))
    );
    return 0; // should never reach here
}

// Notes
// -----
// The burn_mips() and the count_mips() should all consume as many MIPS as they're offered. And
// they should all get the SAME number of MIPS.
// print_mips() uses almost no MIPS -- we can assume it's zero.
// So, with 600 MIPS total, 6 cores using X MIPS, 1 core using none and the mic array using Y MIPS...
//  600 = 6*X + Y  -->  Y = 600 - 6*X

// If we're using the ISR we'll use 5 burn_mips(). Otherwise just 4. Either way the printed MIPS will
// be all the mic array work.
