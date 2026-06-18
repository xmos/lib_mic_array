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
#include "sw_pll.h"

#define APP_FILENAME ("mic_array_output.bin")

DECLARE_JOB(user_mic, (chanend_t));
DECLARE_JOB(user_audio, (chanend_t));

static inline
void _delay_ticks(unsigned ticks) {
  hwtimer_t tmr = hwtimer_alloc();
  hwtimer_delay(tmr, ticks);
  hwtimer_free(tmr);
}

static inline
void _delay_milliseconds(unsigned delay) {
  hwtimer_t tmr = hwtimer_alloc();
  hwtimer_delay(tmr, delay * XS1_TIMER_MHZ * 1000);
  hwtimer_free(tmr);
}

void hwtimer_delay_milliseconds(unsigned delay) {
  _delay_milliseconds(delay);
}

void delay_ticks_longlong(unsigned long long ticks) {
  _delay_ticks(ticks);
}

pdm_rx_resources_t pdm_res_ddr = PDM_RX_RESOURCES_DDR(
    PORT_MCLK_IN,
    PORT_PDM_CLK,
    PORT_PDM_DATA,
    MIC_ARRAY_CONFIG_MCLK_FREQ,
    MIC_ARRAY_CONFIG_PDM_FREQ,
    MIC_CLKBLK_A,
    MIC_CLKBLK_B);

pdm_rx_resources_t pdm_res_sdr = PDM_RX_RESOURCES_SDR(
    PORT_MCLK_IN,
    PORT_PDM_CLK,
    PORT_PDM_DATA,
    MIC_ARRAY_CONFIG_MCLK_FREQ,
    MIC_ARRAY_CONFIG_PDM_FREQ,
    MIC_CLKBLK_A);

void user_mic(chanend_t c_mic_audio)
{
    int ret = sw_pll_fixed_clock(MIC_ARRAY_CONFIG_MCLK_FREQ, SW_PLL_TILE_1);
    xassert(ret == 0 && "Error: Failed to configure PLL for MCLK generation");
    while (1)
    {
        unsigned override = chan_in_word(c_mic_audio);
        printf("mic init %u\n", override);
        if (override == 2) {return;}
        if (override) {
            mic_array_enable_1mic_override();
            mic_array_init(&pdm_res_sdr, NULL, APP_OUT_FREQ_HZ);
        }
        else {
            mic_array_init(&pdm_res_ddr, NULL, APP_OUT_FREQ_HZ);
        }

        mic_array_start(c_mic_audio);
        printf("mic array exited\n");
    }
}

void user_audio(chanend_t c_mic_audio)
{
    // init mic array for 1 mic
    chan_out_word(c_mic_audio, 1);
    uint32_t chans_read = 1;

    static int32_t WORD_ALIGNED tmp_buff[APP_BUFF_SIZE] = {0};
    int32_t *buff_ptr = &tmp_buff[0];
    unsigned frame_counter = APP_N_FRAMES;
    int32_t samps[APP_MIC_COUNT * APP_N_SAMPLES] = {0};

    hwtimer_t tmr = hwtimer_alloc();
    unsigned t0 = 0, t1 = 0;
    unsigned t2 = 0, t3 = 0;
    uint64_t num = 0;
    uint64_t den = 0;

    printf("record start\n");
    t2 = hwtimer_get_time(tmr);
    while (frame_counter--)
    {
        // at APP_FRAME_TRANS reinitialise mic array with 2 mics
        if (frame_counter == APP_FRAME_TRANS) {
            printf("restarting mic array\n");
            ma_shutdown(c_mic_audio);
            chan_out_word(c_mic_audio, 0);
            chans_read = APP_MIC_COUNT;
            delay_milliseconds(900);
        }

        t0 = hwtimer_get_time(tmr);
        ma_frame_rx(samps, (chanend_t)c_mic_audio, chans_read, APP_N_SAMPLES);

        for (unsigned i = 0; i < APP_N_SAMPLES * APP_MIC_COUNT; i ++) {
            buff_ptr[i] = samps[i];
        }
        //buff_ptr[0] = samps[0];
        //buff_ptr[1] = samps[1];
        buff_ptr += APP_N_SAMPLES * APP_MIC_COUNT;

        t1 = hwtimer_get_time(tmr);
        num += (t1 - t0);
        den += 1;
    }
    t3 = hwtimer_get_time(tmr);
    printf("record end\n");

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
    chan_out_word(c_mic_audio, 2);
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
