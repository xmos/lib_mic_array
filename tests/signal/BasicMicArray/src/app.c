// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <print.h>
#include <platform.h>
#include <xcore/select.h>
#include <xcore/parallel.h>
#include <xcore/chanend.h>
#include <xcore/channel.h>
#include <xcore/hwtimer.h>
#include <xcore/channel_streaming.h>
#include <xscope.h>

#include "mic_array.h"

#if USE_CUSTOM_FILTER
#include "custom_filter.h"
#endif

#define BUFF_SIZE    (256)

typedef chanend_t streaming_chanend_t;

DECLARE_JOB(app_output_task, (chanend_t, chanend_t));
DECLARE_JOB(app_fifo_to_xscope_task, (chanend_t));
DECLARE_JOB(app_mic, (chanend_t, chanend_t));
DECLARE_JOB(host_words_to_app, (chanend_t, streaming_chanend_t));


typedef struct {
  unsigned stg1_tap_count;
  unsigned stg1_decimation_factor;
  unsigned stg2_tap_count;
  unsigned stg2_decimation_factor;
  unsigned stg3_tap_count;
  unsigned stg3_decimation_factor;
  int stg2_shr;
  int stg3_shr;
  uint32_t *stg1_coef_ptr;
  int32_t *stg2_coef_ptr;
  int32_t *stg3_coef_ptr;
}filt_config_t;

// ------------------------------- HELPER FUNCTIONS -------------------------------

static inline
void hwtimer_delay_microseconds(unsigned delay) {
  hwtimer_t tmr = hwtimer_alloc();
  hwtimer_delay(tmr, delay * XS1_TIMER_MHZ);
  hwtimer_free(tmr);
}

static 
void get_filter_config(unsigned fs, filt_config_t *cfg) {
#if !USE_CUSTOM_FILTER
  cfg->stg1_tap_count = 256;
  cfg->stg1_decimation_factor = 32;

  cfg->stg3_tap_count = 0;
  cfg->stg3_decimation_factor = 1; // set as 1 to not mess up blocksize calculation at the host end for 2 stage decimator
  cfg->stg3_coef_ptr = NULL;
  cfg->stg3_shr = 0;
  if(fs == 16000) {
    cfg->stg2_tap_count = STAGE2_TAP_COUNT;
    cfg->stg2_decimation_factor = STAGE2_DEC_FACTOR;
    cfg->stg1_coef_ptr = stage1_coef;
    cfg->stg2_coef_ptr = stage2_coef;
    cfg->stg2_shr = stage2_shr;
  }
  else if(fs == 32000) {
    cfg->stg2_tap_count = MIC_ARRAY_32K_STAGE_2_TAP_COUNT;
    cfg->stg2_decimation_factor = 3;
    cfg->stg1_coef_ptr = stage1_32k_coefs;
    cfg->stg2_coef_ptr = stage2_32k_coefs;
    cfg->stg2_shr = stage2_32k_shift;
  }
  else if(fs == 48000) {
    cfg->stg2_tap_count = MIC_ARRAY_48K_STAGE_2_TAP_COUNT;
    cfg->stg2_decimation_factor = 2;
    cfg->stg1_coef_ptr = stage1_48k_coefs;
    cfg->stg2_coef_ptr = stage2_48k_coefs;
    cfg->stg2_shr = stage2_48k_shift;
  }
#else
  cfg->stg1_tap_count = CUSTOM_FILTER_STG1_TAP_COUNT;
  cfg->stg1_decimation_factor = CUSTOM_FILTER_STG1_DECIMATION_FACTOR;
  cfg->stg2_tap_count = CUSTOM_FILTER_STG2_TAP_COUNT;
  cfg->stg2_decimation_factor = CUSTOM_FILTER_STG2_DECIMATION_FACTOR;
  cfg->stg1_coef_ptr = custom_filter_stg1_coef;
  cfg->stg2_coef_ptr = custom_filter_stg2_coef;
  cfg->stg2_shr = CUSTOM_FILTER_STG2_SHR;
#if (NUM_DECIMATION_STAGES==3)
  cfg->stg3_tap_count = CUSTOM_FILTER_STG3_TAP_COUNT;
  cfg->stg3_decimation_factor = CUSTOM_FILTER_STG3_DECIMATION_FACTOR;
  cfg->stg3_coef_ptr = custom_filter_stg3_coef;
  cfg->stg3_shr = CUSTOM_FILTER_STG3_SHR;
#else
  cfg->stg3_tap_count = 0;
  cfg->stg3_decimation_factor = 1; // for PDM RX block size calculation in the test to work for both 2 and 3 stage filters
  cfg->stg3_coef_ptr = nullptr;
  cfg->stg3_shr = 0;
#endif
#endif
}

static inline
void app_print_filters()
{
  filt_config_t filt_cfg;
  get_filter_config(APP_SAMP_FREQ, &filt_cfg);

  unsigned stg1_tap_words = filt_cfg.stg1_tap_count / 2;


  printf("stage1 filter length: %d 16bit coefs -> %d 32b words\n", stg1_tap_words*2, stg1_tap_words);
  int initial_list = stg1_tap_words/4;
  printf("stage1_coef = [\n");
  for(int a = 0; a < initial_list; a++){
    printf("0x%08X, 0x%08X, 0x%08X, 0x%08X, \n",
      filt_cfg.stg1_coef_ptr[a*4+0], filt_cfg.stg1_coef_ptr[a*4+1],
      filt_cfg.stg1_coef_ptr[a*4+2], filt_cfg.stg1_coef_ptr[a*4+3]);
  }
  for(int a = initial_list*4; a < stg1_tap_words; a++){
    printf("0x%08X, ", filt_cfg.stg1_coef_ptr[a]);
  }
  printf("]\n");

  printf("stage2 filter length: %d\n", filt_cfg.stg2_tap_count);
  printf("stage2_coef = [\n");
  initial_list = filt_cfg.stg2_tap_count/4;
  for(int a = 0; a < initial_list; a++){
    printf("0x%08X, 0x%08X, 0x%08X, 0x%08X, \n",
      filt_cfg.stg2_coef_ptr[4*a+0], filt_cfg.stg2_coef_ptr[4*a+1],
      filt_cfg.stg2_coef_ptr[4*a+2], filt_cfg.stg2_coef_ptr[4*a+3]);
  }
  for(int a = initial_list*4; a < filt_cfg.stg2_tap_count; a++){
    printf("0x%08X, ", filt_cfg.stg2_coef_ptr[a]);
  }
  printf("]\n");

  printf("stage2_shr = %d\n", filt_cfg.stg2_shr);
}

static inline
void cmd_print_msg(unsigned i){
    const char* msg[4] = {
        "[CMD] Resume data loop.\n",
        "[CMD] Terminate application.\n",
        "[CMD] Print Filters.\n",
        "[CMD] Unknown command.\n"
    };
    printf("%s\n", msg[i]);
}

static inline
void cmd_perform_action(unsigned cmd){
    switch(cmd){
        case 0:  break;
        case 1:  exit(0); break;
        case 2:  app_print_filters(); break;
        default: assert(0); break;
    }
}

static inline
void cmd_loop(chanend_t c_from_host)
{
  char cmd_buff[BUFF_SIZE];
  int pp;
  SELECT_RES(
    CASE_THEN(c_from_host, c_from_host_handler)
  )
  c_from_host_handler:{
    xscope_data_from_host(c_from_host, &cmd_buff[0], &pp);
    assert((pp-1) == 4);
    uint32_t cmd = ((uint32_t*)(void*) &cmd_buff[0])[0];
    cmd_print_msg(cmd);
    cmd_perform_action(cmd);
    continue;
  }
}

static inline
int send_words_to_app(streaming_chanend_t c_to_app, char* buff, int buff_lvl)
{
  int* next_word = (int*)(void*) &buff[0];
  while(buff_lvl >= sizeof(int)){
    s_chan_out_word(c_to_app, next_word[0]);
    next_word++;
    buff_lvl -= sizeof(int);
    hwtimer_delay_microseconds(15);
  }
  if(buff_lvl) 
  {
    memmove(&buff[0], &next_word[0], buff_lvl);
  }
  return buff_lvl;
}


extern void _mic_array_override_pdm_port_c(chanend_t c_pdm);

// We'll be using a fairly standard mic array setup here, with one big
// exception. Instead of feeding the PDM rx service with a port, we're going
// to feed it from a streaming channel. Under the surface it is just using an
// IN instruction on a resource. As long as it's given a 32-bit word, it
// doesn't particularly care what the resource is.
// Since we're not using a port, we also don't need to worry about setting up
// clocks or any of that silliness

pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(
                                PORT_MCLK_IN,
                                PORT_PDM_CLK,
                                PORT_PDM_DATA,
                                24576000,
                                3072000,
                                XS1_CLKBLK_1);

#if USE_CUSTOM_FILTER
static void init_mic_conf(mic_array_conf_t *mic_array_conf, mic_array_filter_conf_t filter_conf[NUM_DECIMATION_STAGES], unsigned *channel_map)
{
  static int32_t stg1_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][8];
  static int32_t stg2_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][CUSTOM_FILTER_STG2_TAP_COUNT];
  memset(mic_array_conf, 0, sizeof(mic_array_conf_t));

  //decimator
  mic_array_conf->decimator_conf.filter_conf = &filter_conf[0];
  mic_array_conf->decimator_conf.num_filter_stages = NUM_DECIMATION_STAGES;
  // stage 1
  filter_conf[0].coef = (int32_t*)custom_filter_stg1_coef;
  filter_conf[0].num_taps = CUSTOM_FILTER_STG1_TAP_COUNT;
  filter_conf[0].decimation_factor = CUSTOM_FILTER_STG1_DECIMATION_FACTOR;
  filter_conf[0].state = (int32_t*)stg1_filter_state;
  filter_conf[0].shr = CUSTOM_FILTER_STG1_SHR;
  filter_conf[0].state_words_per_channel = filter_conf[0].num_taps/32;
  // stage 2
  filter_conf[1].coef = (int32_t*)custom_filter_stg2_coef;
  filter_conf[1].num_taps = CUSTOM_FILTER_STG2_TAP_COUNT;
  filter_conf[1].decimation_factor = CUSTOM_FILTER_STG2_DECIMATION_FACTOR;
  filter_conf[1].state = (int32_t*)stg2_filter_state;
  filter_conf[1].shr = CUSTOM_FILTER_STG2_SHR;
  filter_conf[1].state_words_per_channel = CUSTOM_FILTER_STG2_TAP_COUNT;
  // stage 3
#if (NUM_DECIMATION_STAGES==3)
  static int32_t stg3_filter_state[MIC_ARRAY_CONFIG_MIC_COUNT][CUSTOM_FILTER_STG3_TAP_COUNT];
  filter_conf[2].coef = (int32_t*)custom_filter_stg3_coef;
  filter_conf[2].num_taps = CUSTOM_FILTER_STG3_TAP_COUNT;
  filter_conf[2].decimation_factor = CUSTOM_FILTER_STG3_DECIMATION_FACTOR;
  filter_conf[2].state = (int32_t*)stg3_filter_state;
  filter_conf[2].shr = CUSTOM_FILTER_STG3_SHR;
  filter_conf[2].state_words_per_channel = CUSTOM_FILTER_STG3_TAP_COUNT;
#else
  #define CUSTOM_FILTER_STG3_DECIMATION_FACTOR (1) /*for PDM RX block size calculation below to work for both 2 and 3 stage filter*/
#endif
  // pdm rx
  static uint32_t pdmrx_out_block[MIC_ARRAY_CONFIG_MIC_COUNT][CUSTOM_FILTER_STG2_DECIMATION_FACTOR * CUSTOM_FILTER_STG3_DECIMATION_FACTOR];
  static uint32_t __attribute__((aligned(8))) pdmrx_out_block_double_buf[2][MIC_ARRAY_CONFIG_MIC_COUNT * CUSTOM_FILTER_STG2_DECIMATION_FACTOR * CUSTOM_FILTER_STG3_DECIMATION_FACTOR];
  mic_array_conf->pdmrx_conf.pdm_out_words_per_channel = CUSTOM_FILTER_STG2_DECIMATION_FACTOR * CUSTOM_FILTER_STG3_DECIMATION_FACTOR;
  mic_array_conf->pdmrx_conf.pdm_out_block = (uint32_t*)pdmrx_out_block;
  mic_array_conf->pdmrx_conf.pdm_in_double_buf = (uint32_t*)pdmrx_out_block_double_buf;
  mic_array_conf->pdmrx_conf.channel_map = channel_map;
}
#endif


// ------------------------------- THREADS -------------------------------

void app_mic(
    chanend_t c_pdm_in,
    chanend_t c_frames_out) //non-streaming
{
#if !USE_CUSTOM_FILTER
  mic_array_init(&pdm_res, NULL, APP_SAMP_FREQ);
#else
  mic_array_conf_t mic_array_conf;
  mic_array_filter_conf_t filter_conf[NUM_DECIMATION_STAGES];
  init_mic_conf(&mic_array_conf, filter_conf, NULL);
  mic_array_init_custom_filter(&pdm_res, &mic_array_conf);
#endif
  _mic_array_override_pdm_port_c((port_t)c_pdm_in); // get pdm input from channel instead of port.
                                                  // mic_array_init() calls mic_array_resources_configure which would crash
                                                  // if a chanend were to be passed instead of a port for the pdm data port, so
                                                  // this overriding has to be done only after calling mic_array_init()
  mic_array_start(c_frames_out);
}

// Sometimes xscope doesn't keep up causing backpressure so add a FIFO to decouple this, at least up to 8 frames.
// We can buffer up to 8 chars in a same tile chanend.
const unsigned fifo_entries = 8;
typedef int32_t ma_frame_t[MIC_ARRAY_CONFIG_MIC_COUNT][MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME];
ma_frame_t frame_fifo[fifo_entries];


void app_output_task(chanend_t c_frames_in, chanend_t c_fifo)
{
  // Before listening for any frames, use the META_OUT xscope probe to report
  // our configuration to the host. This will help make sure the right version
  // of this application is being used.
  filt_config_t filt_cfg;
  get_filter_config(APP_SAMP_FREQ, &filt_cfg);

  xscope_int(META_OUT, MIC_ARRAY_CONFIG_MIC_COUNT);
  xscope_int(META_OUT, filt_cfg.stg1_tap_count);
  xscope_int(META_OUT, filt_cfg.stg1_decimation_factor);
  xscope_int(META_OUT, filt_cfg.stg2_tap_count);
  xscope_int(META_OUT, filt_cfg.stg2_decimation_factor);
  xscope_int(META_OUT, filt_cfg.stg3_tap_count);
  xscope_int(META_OUT, filt_cfg.stg3_decimation_factor);
  xscope_int(META_OUT, MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);
  xscope_int(META_OUT, MIC_ARRAY_CONFIG_USE_PDM_ISR); // Using interrupt


  // receive the output of the mic array and send it to the host via a fifo to decouple the backpressure from xscope
  int32_t frame[MIC_ARRAY_CONFIG_MIC_COUNT][MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME];
  uint8_t fifo_idx = 0;

  while(1){
    ma_frame_rx(&frame[0][0], c_frames_in, MIC_ARRAY_CONFIG_MIC_COUNT, MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);
    memcpy(frame_fifo[fifo_idx], &frame[0][0], sizeof(ma_frame_t));
    int t0 = get_reference_time();
    chanend_out_byte(c_fifo, fifo_idx++);
    int t1 = get_reference_time();
    if(t1 - t0 > 10){
        printstrln("ERROR - Timing fail");
    }
    if(fifo_idx == fifo_entries){
        fifo_idx = 0;
    }
  }
}


void app_fifo_to_xscope_task(chanend_t c_fifo)
{
    while(1){
        uint8_t idx = chanend_in_byte(c_fifo);
        ma_frame_t *ptr = &frame_fifo[idx];

        // Send it to host sample by sample rather than channel by channel
        for(int smp = 0; smp < MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME; smp++) {
          for(int ch = 0; ch < MIC_ARRAY_CONFIG_MIC_COUNT; ch++){
            xscope_int(DATA_OUT, (*ptr)[ch][smp]);
          }
        }
    }
}


void host_words_to_app(chanend_t c_from_host, streaming_chanend_t c_to_app)
{
  xscope_connect_data_from_host(c_from_host);

  char buff[100*BUFF_SIZE+3];
  int buff_lvl = 0;
  int dd = 0;

  SELECT_RES(
    CASE_THEN(c_from_host, c_from_host_handler)
  ){
  c_from_host_handler:{
    xscope_data_from_host(c_from_host, &buff[0], &dd);
    dd--;
        buff_lvl += dd;
        if(dd == 0) {
            cmd_loop(c_from_host);
        }
        else {
            buff_lvl = send_words_to_app(c_to_app, buff, buff_lvl);
        }
    continue;
  }}
}


int main(){
  channel_t c_frames = chan_alloc();
  channel_t c_fifo = chan_alloc();
  streaming_channel_t c_to_app = s_chan_alloc();

  // xscope init note: only one channel end is needed
  // the second one and the xscope service will be 
  // automatically started and routed by the tools
  chanend_t xscope_chan = chanend_alloc();
  xscope_mode_lossless();

  PAR_JOBS(
    PJOB(app_mic, (c_to_app.end_a, c_frames.end_a)),
    PJOB(app_output_task, (c_frames.end_b, c_fifo.end_a)),
    PJOB(app_fifo_to_xscope_task, (c_fifo.end_b)),
    PJOB(host_words_to_app, (xscope_chan, c_to_app.end_b))
  );
  s_chan_free(c_to_app);
  chan_free(c_frames);
  chan_free(c_fifo);
  return 0;
}
