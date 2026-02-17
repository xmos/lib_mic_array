// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include <platform.h>
#include <xcore/chanend.h>
#include <xcore/channel.h>
#include <xcore/parallel.h>

#include "mic_array.h"
#include "device_pll_ctrl.h"

// -------------------- Frecuency and Port definitions --------------------
#define MIC_ARRAY_CONFIG_MCLK_FREQ (24576000)
#define MIC_ARRAY_CONFIG_PDM_FREQ (3072000)
#define MIC_ARRAY_CONFIG_PORT_MCLK XS1_PORT_1D       /* X0D11, J14 - Pin 15, '11' */
#define MIC_ARRAY_CONFIG_PORT_PDM_CLK PORT_MIC_CLK   /* X0D00, J14 - Pin 2, '00' */
#define MIC_ARRAY_CONFIG_PORT_PDM_DATA PORT_MIC_DATA /* X0D14..X0D21 | J14 - Pin 3,5,12,14 and Pin 6,7,10,11 */
#define MIC_ARRAY_CONFIG_CLOCK_BLOCK_A XS1_CLKBLK_2
// ------------------------------------------------------------

// App defines
#define APP_N_SAMPLES (320)
#define APP_OUT_FREQ_HZ (16000)
#define APP_SAMPLE_SECONDS (2)
#define APP_N_FRAMES (APP_OUT_FREQ_HZ * APP_SAMPLE_SECONDS / APP_N_SAMPLES)
#define APP_BUFF_SIZE (APP_N_FRAMES * APP_N_SAMPLES)
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

void user_mic(chanend_t c_mic_audio)
{
    printf("Mic Init\n");
    device_pll_init();
    mic_array_init(&pdm_res, NULL, APP_OUT_FREQ_HZ);
    mic_array_start(c_mic_audio);
}

void user_audio(chanend_t c_mic_audio)
{
    int32_t WORD_ALIGNED tmp_buff[APP_BUFF_SIZE] = {0};
    int32_t *buff_ptr = &tmp_buff[0];
    unsigned frame_counter = APP_N_FRAMES;
    while (frame_counter--)
    {
        ma_frame_rx(buff_ptr, (chanend_t)c_mic_audio, MIC_ARRAY_CONFIG_MIC_COUNT, APP_N_SAMPLES);
        buff_ptr += APP_N_SAMPLES;
        for (unsigned i = 0; i < APP_N_SAMPLES; i++)
        {
            tmp_buff[i] <<= 6;
        }
    }

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
