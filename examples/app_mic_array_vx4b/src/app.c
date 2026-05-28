// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <xscope.h>
#include <xcore/chanend.h>
#include <xcore/channel.h>
#include <xcore/parallel.h>
#include <xcore/hwtimer.h>

#include "app_config.h"
#include "mic_array.h"
#include "device_pll_ctrl.h"
#include "small_768k_to_12k_filter.h"

#define APP_FILENAME ("mic_array_output.bin")

DECLARE_JOB(user_mic, (chanend_t));
DECLARE_JOB(user_audio, (chanend_t));

static pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(
    MIC_ARRAY_CONFIG_PORT_MCLK,
    MIC_ARRAY_CONFIG_PORT_PDM_CLK,
    MIC_ARRAY_CONFIG_PORT_PDM_DATA,
    MIC_ARRAY_CONFIG_MCLK_FREQ,
    MIC_ARRAY_CONFIG_PDM_FREQ,
    MIC_ARRAY_CONFIG_CLOCK_BLOCK_A);

void init_mic_conf(mic_array_conf_t *mic_array_conf, mic_array_filter_conf_t filter_conf[2], unsigned *channel_map)
{
  static int32_t stg1_filter_state[APP_MIC_COUNT][8];
  static int32_t stg2_filter_state[APP_MIC_COUNT][SMALL_768K_TO_12K_FILTER_STG2_TAP_COUNT];
  memset(mic_array_conf, 0, sizeof(mic_array_conf_t));

  //decimator
  mic_array_conf->decimator_conf.filter_conf = &filter_conf[0];
  mic_array_conf->decimator_conf.num_filter_stages = 2;
  // filter stage 1
  filter_conf[0].coef = (int32_t*)small_768k_to_12k_filter_stg1_coef;
  filter_conf[0].num_taps = SMALL_768K_TO_12K_FILTER_STG1_TAP_COUNT;
  filter_conf[0].decimation_factor = SMALL_768K_TO_12K_FILTER_STG1_DECIMATION_FACTOR;
  filter_conf[0].state = (int32_t*)stg1_filter_state;
  filter_conf[0].shr = SMALL_768K_TO_12K_FILTER_STG1_SHR;
  filter_conf[0].state_words_per_channel = filter_conf[0].num_taps/32; // works on 1-bit samples
  // filter stage 2
  filter_conf[1].coef = (int32_t*)small_768k_to_12k_filter_stg2_coef;
  filter_conf[1].num_taps = SMALL_768K_TO_12K_FILTER_STG2_TAP_COUNT;
  filter_conf[1].decimation_factor = SMALL_768K_TO_12K_FILTER_STG2_DECIMATION_FACTOR;
  filter_conf[1].state = (int32_t*)stg2_filter_state;
  filter_conf[1].shr = SMALL_768K_TO_12K_FILTER_STG2_SHR;
  filter_conf[1].state_words_per_channel = SMALL_768K_TO_12K_FILTER_STG2_TAP_COUNT;

  // pdm rx
  static uint32_t pdmrx_out_block[APP_MIC_COUNT][SMALL_768K_TO_12K_FILTER_STG2_DECIMATION_FACTOR];
  static uint32_t pdmrx_out_block_double_buf[2][APP_MIC_COUNT * SMALL_768K_TO_12K_FILTER_STG2_DECIMATION_FACTOR] __attribute__((aligned(8)));
  mic_array_conf->pdmrx_conf.pdm_out_words_per_channel = SMALL_768K_TO_12K_FILTER_STG2_DECIMATION_FACTOR;
  mic_array_conf->pdmrx_conf.pdm_out_block = (uint32_t*)pdmrx_out_block;
  mic_array_conf->pdmrx_conf.pdm_in_double_buf = (uint32_t*)pdmrx_out_block_double_buf;
  mic_array_conf->pdmrx_conf.channel_map = channel_map;
}

void user_mic(chanend_t c_mic_audio)
{
    printf("mic init\n");
    device_pll_init();
    unsigned channel_map[1] = {0};
    mic_array_conf_t mic_array_conf;
    mic_array_filter_conf_t filter_conf[2];
    init_mic_conf(&mic_array_conf, filter_conf, channel_map);
    mic_array_init_custom_filter(&pdm_res, &mic_array_conf);
    mic_array_start(c_mic_audio);
}

void user_audio(chanend_t c_mic_audio)
{
    static int32_t WORD_ALIGNED tmp_buff[APP_BUFF_SIZE] = {0};
    int32_t *buff_ptr = &tmp_buff[0];
    unsigned frame_counter = APP_N_FRAMES;

    hwtimer_t tmr = hwtimer_alloc();
    unsigned t0 = 0, t1 = 0;
    unsigned t2 = 0, t3 = 0;
    uint64_t num = 0;
    uint64_t den = 0;

    printf("mic start\n");
    t2 = hwtimer_get_time(tmr);
    while (frame_counter--)
    {
        t0 = hwtimer_get_time(tmr);
        ma_frame_rx(buff_ptr, (chanend_t)c_mic_audio, MIC_ARRAY_CONFIG_MIC_COUNT, APP_N_SAMPLES);
        buff_ptr += APP_N_SAMPLES;
        t1 = hwtimer_get_time(tmr);
        num += (t1 - t0);
        den += 1;
    }
    t3 = hwtimer_get_time(tmr);
    printf("mic end\n");

    // Profile the average time taken per frame
    const float ma_expected = (float)(APP_N_SAMPLES) / (float)(APP_OUT_FREQ_HZ);
    const float tilef = 600.0;
    const float ref = tilef / (5.0 + 1.0);

    float avg = (float)num / (float)den;
    float total = (float)(t3 - t2);
    float avg_us =  avg / ref;
    float total_us = total / ref;
    float ma_exp_us = ma_expected * 1e6;
    float perc_err = ((avg_us - ma_exp_us) / ma_exp_us) * 100.0;

    printf("Tile freq: %.2f MHz\n", tilef);
    printf("Reference freq: %.2f MHz\n", ref);
    printf("ma_frame_rx avg: %.2f ticks\n", avg);
    printf("ma_frame_rx avg: %.2f us\n", avg_us);
    printf("ma_frame_rx expected: %.2f us\n", ma_exp_us);
    printf("ma_frame_rx error: %.2f %%\n", perc_err);
    printf("total ticks: %.2f\n", total);
    printf("total us: %.2f us\n", total_us);

    // write samples to a binary file
    printf("Writing output to %s\n", APP_FILENAME);
    FILE *f = fopen(APP_FILENAME, "wb");
    assert(f != NULL);
    fwrite(tmp_buff, sizeof(int32_t), APP_BUFF_SIZE, f);
    fclose(f);
    ma_shutdown(c_mic_audio);
    printf("Done\n");
}

void main_tile_1(){
    channel_t c_mic_audio = chan_alloc();
    xscope_mode_lossless();

    // Parallel Jobs
    PAR_JOBS(
        PJOB(user_mic, (c_mic_audio.end_a)),
        PJOB(user_audio, (c_mic_audio.end_b))
    );
    chan_free(c_mic_audio);
}

void main_tile_0(){
    // intentionally left empty
    return;
}
