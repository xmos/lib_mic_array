// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "xk_voice_l71/board.h"
#include "app_config.h"
#include "mic_array.h"
#include "app.h"
#include "good_2_stage_filter.h"

#ifndef APP_MIC_IN_COUNT
  #define APP_MIC_IN_COUNT (APP_MIC_COUNT)
#endif

static const xk_voice_l71_config_t hw_config = {
                                                CLK_FIXED,
                                                ENABLE_MCLK | ENABLE_I2S,
                                                DAC_DIN_SEC,
                                                MCLK_48
                                               };

// mic array resources
on tile[PORT_PDM_CLK_TILE_NUM]: in port p_mclk =    PORT_MCLK_IN;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk =   PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data =  PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a =      XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b =      XS1_CLKBLK_2;

unsafe{

void AudioHwInit()
{
    xk_voice_l71_AudioHwInit(hw_config);
    xk_voice_l71_AudioHwConfig(hw_config, APP_AUDIO_SAMPLE_RATE, MCLK_48);
    return;
}

void init_mic_conf(mic_array_conf_t &mic_array_conf, unsigned *channel_map)
{
  static int32_t stg1_filter_state[APP_MIC_COUNT][8];
  static int32_t stg2_filter_state[APP_MIC_COUNT][GOOD_2_STAGE_FILTER_STG2_TAP_COUNT];
  memset(&mic_array_conf, 0, sizeof(mic_array_conf_t));

  //decimator
  // stage 1
  mic_array_conf.decimator_conf.filter_conf[0].coef = (int32_t*)good_2_stage_filter_stg1_coef;
  mic_array_conf.decimator_conf.filter_conf[0].num_taps = GOOD_2_STAGE_FILTER_STG1_TAP_COUNT;
  mic_array_conf.decimator_conf.filter_conf[0].decimation_factor = GOOD_2_STAGE_FILTER_STG1_DECIMATION_FACTOR;
  mic_array_conf.decimator_conf.filter_conf[0].state = (int32_t*)stg1_filter_state;
  mic_array_conf.decimator_conf.filter_conf[0].shr = GOOD_2_STAGE_FILTER_STG1_SHR;
  mic_array_conf.decimator_conf.filter_conf[0].state_size = 8;
  // stage 2
  mic_array_conf.decimator_conf.filter_conf[1].coef = (int32_t*)good_2_stage_filter_stg2_coef;
  mic_array_conf.decimator_conf.filter_conf[1].num_taps = GOOD_2_STAGE_FILTER_STG2_TAP_COUNT;
  mic_array_conf.decimator_conf.filter_conf[1].decimation_factor = GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR;
  mic_array_conf.decimator_conf.filter_conf[1].state = (int32_t*)stg2_filter_state;
  mic_array_conf.decimator_conf.filter_conf[1].shr = GOOD_2_STAGE_FILTER_STG2_SHR;
  mic_array_conf.decimator_conf.filter_conf[1].state_size = GOOD_2_STAGE_FILTER_STG2_TAP_COUNT;

  // pdm rx
  static uint32_t pdmrx_out_block[APP_MIC_COUNT][GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR];
  static uint32_t __attribute__((aligned(8))) pdmrx_out_block_double_buf[2][APP_MIC_COUNT * GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR];
  mic_array_conf.pdmrx_conf.num_mics = APP_MIC_COUNT;
  mic_array_conf.pdmrx_conf.num_mics_in = APP_MIC_IN_COUNT;
  mic_array_conf.pdmrx_conf.out_block_size = GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR;
  mic_array_conf.pdmrx_conf.out_block = (uint32_t*)pdmrx_out_block;
  mic_array_conf.pdmrx_conf.out_block_double_buf = (uint32_t*)pdmrx_out_block_double_buf;
  mic_array_conf.pdmrx_conf.channel_map = channel_map;
}

int main() {
  chan c_audio_frames;
  chan c_i2c;

  par {

    on tile[0]: {
      xk_voice_l71_AudioHwRemote(c_i2c); // Startup remote I2C master server task
    }


    on tile[1]: {
      xk_voice_l71_AudioHwChanInit(c_i2c);
      AudioHwInit();

#if (MIC_ARRAY_CONFIG_MIC_COUNT == 2)
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, MCLK_48, PDM_FREQ, clk_a, clk_b);
#else
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(p_mclk, p_pdm_clk, p_pdm_data, MCLK_48, PDM_FREQ, clk_a);
#endif

      unsigned channel_map[2] = {0,1};
      mic_array_conf_t mic_array_conf;
      init_mic_conf(mic_array_conf, channel_map);
      mic_array_init_custom_filters(&pdm_res, &mic_array_conf);

      par {
        mic_array_start((chanend_t) c_audio_frames);

        app_i2s_task( (chanend_t)c_audio_frames );
      }
    }
  }

  return 0;
}
}
