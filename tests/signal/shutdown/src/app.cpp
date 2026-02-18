// Copyright 2025-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>
#include <string.h>
#include <platform.h>

#include <xcore/channel.h>
#include <xcore/hwtimer.h>
#include <xcore/channel_streaming.h>
#include <xcore/select.h>
#include <xcore/parallel.h>

#include "app.h"
#include "mic_array/mic_array_conf_full.h"
#include <print.h>

DECLARE_JOB(app_controller, (chanend_t, chanend_t));
DECLARE_JOB(app_mic, (chanend_t, chanend_t));
DECLARE_JOB(app_mic_interface, (chanend_t, chanend_t));

static inline 
void hwtimer_delay_ticks(unsigned ticks){
  hwtimer_t tmr = hwtimer_alloc();
  hwtimer_delay(tmr, ticks);
  hwtimer_free(tmr);
}

/**
 * @brief Triggers an assertion if the test exceeds a timeout period.
 *
 */
void assert_when_timeout()
{
  hwtimer_t t = hwtimer_alloc();
  unsigned long now = hwtimer_get_time(t);
  const int timeout_s = 5;

  hwtimer_set_trigger_time(t, now + (XS1_TIMER_HZ*timeout_s));
  SELECT_RES(
    CASE_THEN(t, timer_handler))
  {
    timer_handler:
      assert(0); // Error: test timed out due to deadlock
      break;
  }

  hwtimer_free(t);
}

#define MCLK_FREQ (24576000)
#define PDM_FREQ  (3072000)
pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(
                                PORT_MCLK_IN,
                                PORT_PDM_CLK,
                                PORT_PDM_DATA,
                                MCLK_FREQ,
                                PDM_FREQ,
                                XS1_CLKBLK_1);

const unsigned inter_sample_delay = (32*XS1_TIMER_HZ)/(PDM_FREQ*2); // Delay between 2 consecutive 32bit pdm samples. Assume DDR for fastest rate

extern void _mic_array_override_pdm_port(chanend_t c_pdm);

enum {
    START = 1,
    RECEIVE,
    SHUTDOWN,
};

typedef struct {
    unsigned samp_freq;
    unsigned stg2_df;
    unsigned pdm_samps_per_frame;
    unsigned counter;
}fs_config_t; //configuration related to sampling frequency


// Determines the sequence of events so we can test shutdown happening at the exact instances we want
static inline void send_pdm_frame(chanend_t c, int samples, unsigned delay)
{
    for(int i=0; i<samples; i++)
    {
        s_chan_out_word(c, i);
        hwtimer_delay_ticks(delay);
    }
}

static void update_samp_freq(fs_config_t *p_fs_cfg)
{
    int samp_freqs[3] = {16000, 32000, 48000}; // cycle through the sampling freqs
    int num_samp_freqs = sizeof(samp_freqs)/sizeof(samp_freqs[0]);

    p_fs_cfg->samp_freq = samp_freqs[p_fs_cfg->counter];
    p_fs_cfg->stg2_df = (PDM_FREQ/32)/p_fs_cfg->samp_freq;
    p_fs_cfg->pdm_samps_per_frame = MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME*MIC_ARRAY_CONFIG_MIC_COUNT*p_fs_cfg->stg2_df;
    p_fs_cfg->counter = (p_fs_cfg->counter + 1) % num_samp_freqs; // for next time
}

static void send_cmd(chanend_t c_sync, chanend_t c_pdm_in, unsigned cmd, const fs_config_t *p_fs_cfg)
{
    if(cmd == START) {
        chan_out_word(c_sync, cmd);
        chan_out_word(c_sync, p_fs_cfg->samp_freq);
    }
    else if(cmd == RECEIVE) {
        chan_out_word(c_sync, cmd);
    }
    else if(cmd == SHUTDOWN) {
        chan_out_word(c_sync, cmd);
        // Continue sending PDM since mic array threads only shutdown at PDM frame boundaries.
        // Send enough frames for both mic array and pdmrx to see shutdown and exit
        // Any unsent frames, that cause send_pdm_block to block will be drained
        // after mic array shuts down (note: this is only for the test since we send in pdm over a channel)
        for(int i=0; i<4; i++)
        {
            send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay);
        }
        int temp = chan_in_word(c_sync);
        (void)temp;
    }
}

static void test_start_shutdown_start(chanend_t c_pdm_in, chanend_t c_sync, fs_config_t *p_fs_cfg)
{
    printf("%s\n", __func__);
    update_samp_freq(p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, START, p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, SHUTDOWN, p_fs_cfg); // Trigger shutdown
    printf("%s PASS\n", __func__);
}

static void test_start_receive_shutdown(chanend_t c_pdm_in, chanend_t c_sync, fs_config_t *p_fs_cfg)
{
    printf("%s\n", __func__);
    update_samp_freq(p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, START, p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, RECEIVE, p_fs_cfg);
    send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay);
    send_cmd(c_sync, c_pdm_in, SHUTDOWN, p_fs_cfg);
    printf("%s PASS\n", __func__);
}

static void test_schan_full_pdmrx_blocked(chanend_t c_pdm_in, chanend_t c_sync, fs_config_t *p_fs_cfg)
{
    printf("%s\n", __func__);
    update_samp_freq(p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, START, p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, RECEIVE, p_fs_cfg);
    //send a frame at new samp_freq and make sure this is received, indicating successful restart at the new freq
    send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay);

    // send 4 frames (without receiving) to completely fill the streaming channel (between pdmrx and decimator) buffer
    // and cause pdmrx thread to block
    for(int i=0; i<4; i++)
    {
        // the 1st frame blocks at ma_frame_tx()
        // 2nd frame sits in the streaming chan (between pdmrx and decimator) buffer 1
        // 3rd frame sits in the streaming chan (between pdmrx and decimator) buffer 2
        // 4th frame causes PdmRxService SendBlock to block
        send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay); // this blocks at ma_frame_tx
    }
    send_cmd(c_sync, c_pdm_in, SHUTDOWN, p_fs_cfg); // Trigger shutdown.
    printf("%s PASS\n", __func__);
}

static void test_schan_full(chanend_t c_pdm_in, chanend_t c_sync, fs_config_t *p_fs_cfg)
{
    printf("%s\n", __func__);
    update_samp_freq(p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, START, p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, RECEIVE, p_fs_cfg);
    //send a frame at new samp_freq and make sure this is received, indicating successful restart at the new freq
    send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay);

    // send 3 frames (without receiving) to completely fill the streaming channel (between pdmrx and decimator) buffer
    for(int i=0; i<3; i++)
    {
        // the 1st frame blocks at ma_frame_tx()
        // 2nd frame sits in the streaming chan (between pdmrx and decimator) buffer 1
        // 3rd frame sits in the streaming chan (between pdmrx and decimator) buffer 2
        send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay); // this blocks at ma_frame_tx
    }
    send_cmd(c_sync, c_pdm_in, SHUTDOWN, p_fs_cfg); // Trigger shutdown.
    printf("%s PASS\n", __func__);
}

static void test_schan_partially_full(chanend_t c_pdm_in, chanend_t c_sync, fs_config_t *p_fs_cfg)
{
    printf("%s\n", __func__);
    update_samp_freq(p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, START, p_fs_cfg);
    send_cmd(c_sync, c_pdm_in, RECEIVE, p_fs_cfg);
    //send a frame at new samp_freq and make sure this is received, indicating successful restart at the new freq
    send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay);

    // send 2 frames (without receiving) to patially fill the streaming channel (between pdmrx and decimator) buffer
    for(int i=0; i<2; i++)
    {
        // the 1st frame blocks at ma_frame_tx()
        // 2nd frame sits in the streaming chan (between pdmrx and decimator) buffer 1
        send_pdm_frame(c_pdm_in, p_fs_cfg->pdm_samps_per_frame, inter_sample_delay); // this blocks at ma_frame_tx
    }
    send_cmd(c_sync, c_pdm_in, SHUTDOWN, p_fs_cfg); // Trigger shutdown.
    printf("%s PASS\n", __func__);
}

/**
 * @brief mic array task
 *
 * @param c_pdm_in - chanend over which to receive pdm samples
 * @param c_frames_out - chanend over which to transmit output frames to the app
 */
void app_mic(chanend_t c_pdm_in, chanend_t c_frames_out)
{
    while(1) {
        int fs = chan_in_word(c_frames_out);
        mic_array_init(&pdm_res, NULL, fs);
        _mic_array_override_pdm_port((port_t)c_pdm_in); // get pdm input from channel instead of port.
                                                  // mic_array_init() calls mic_array_resources_configure which would crash
                                                  // if a chanend were to be passed instead of a port for the pdm data port, so
                                                  // this overriding has to be done only after calling mic_array_init()
        mic_array_start(c_frames_out);
        //printf("mic array task exits\n");
        // Drain any pdm in data that's on the c_pdm_in channel to unblock app_controller that might be blocked on send_pdm_frame()
        // Note: this is only test specific where we use a channel pretending to be a port to send in pdm.
        // In reality pdm data is received over a port and doesn't cause anything to block when the mic_array shuts down
        int temp;
        hwtimer_delay_ticks(inter_sample_delay*2); // add some delay to account for delay in send_pdm_frame to allow us to be behind send_pdm_frame
        SELECT_RES(CASE_THEN(c_pdm_in, drain_incoming_pdm),
                 DEFAULT_THEN(empty))
        {
            drain_incoming_pdm:
                temp = s_chan_in_word(c_pdm_in);
                hwtimer_delay_ticks(inter_sample_delay*2);
                (void)temp;
                SELECT_CONTINUE_NO_RESET;

            empty:
                break;
        }
    }
}

/**
 * @brief mic interface task
 *
 * This task interfaces with the mic array - starting/receiving frames from it/shutting the mic array based
 * on commands it receives from the app_controller
 *
 * @param c_sync - chanend over which app_controller coordinates with this task
 * @param c_frames_out - chanend over which to receive frames from the mic array
 */
void app_mic_interface(chanend_t c_sync, chanend_t c_frames_out)
{
    while(1)
    {
        int cmd = chan_in_word(c_sync);
        if(cmd == START)
        {
            int fs = chan_in_word(c_sync);
            chan_out_word(c_frames_out, fs);
        }
        if(cmd == RECEIVE)
        {
            int32_t audio_frame[MIC_ARRAY_CONFIG_MIC_COUNT * MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME];
            ma_frame_rx(audio_frame, c_frames_out, MIC_ARRAY_CONFIG_MIC_COUNT, MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);
            //printf("app_mic_interface() received frame\n");
        }
        else if(cmd == SHUTDOWN)
        {
            //printf("sending shutdown\n");
            ma_shutdown(c_frames_out);
            chan_out_word(c_sync, 1); // indicate shutdown complete to the controller
            //printf("shutdown complete\n");
        }
    }
}

/**
 * @brief controller task
 *
 * This task coodinates mic array tests by acting as a pdm sender to the mic array and coordinating with
 * app_mic_interface() to start/receive frame from/shutdown mic array at appropriate times.
 *
 * The tests test shutting the mic array at various states of the mic and the pdmrx threads. They check that
 * the mic array can shutdown and start without hanging. They don't test the validity of frames received from
 * the mic array in any way - just that after a restart, the app is able to receive frames from the mic array.
 *
 * @param c_pdm_in - chanend over which to send 'pdm' data to the mic array.
 *                   This is used instead of a port for simplicity (not requiring clk setup etc.)
 * @param c_sync - chanend over which app_controller coordinates with the app_mic_interface task
 */
void app_controller(chanend_t c_pdm_in, chanend_t c_sync)
{
    fs_config_t fs_config;
    memset(&fs_config, 0, sizeof(fs_config_t));

    /**
     * Note: All tests need to start with starting the mic array and end with shutting it down.
     * This ensures that there's no dependency from one test to the next and they
     * can be commented out/reordered if required.
     */

    // test that the mic array copes with shutdown right after start
    test_start_shutdown_start(c_pdm_in, c_sync, &fs_config);

    // test start -> receive frame -> shutdown
    // this tests that the mic array can shutdown when none of the threads are waiting on anything
    test_start_receive_shutdown(c_pdm_in, c_sync, &fs_config);

    // test shutdown when:
    // mic thread is blocked on ma_frame_tx
    // pdmrx thread is blocked on a SendBlock
    test_schan_full_pdmrx_blocked(c_pdm_in, c_sync, &fs_config);

    // test shutdown when:
    // mic thread is blocked on ma_frame_tx
    // pdmrx thread is not blocked and there are 2 pending frames in the schan between pdmrx and decimator
    test_schan_full(c_pdm_in, c_sync, &fs_config);

    // test shutdown when:
    // mic thread is blocked on ma_frame_tx
    // pdmrx thread is not blocked and there is 1 pending frame in the schan between pdmrx and decimator
    test_schan_partially_full(c_pdm_in, c_sync, &fs_config);

    printf("PASS\n");
    exit(0);
}

void main_tile_1()
{
    channel_t c_frames_out = chan_alloc();
    channel_t c_sync = chan_alloc();
    streaming_channel_t c_pdm_in = s_chan_alloc();

    PAR_JOBS(
        PJOB(app_controller, (c_pdm_in.end_a, c_sync.end_a)),
        PJOB(app_mic, (c_pdm_in.end_b, c_frames_out.end_a)),
        PJOB(app_mic_interface, (c_sync.end_b, c_frames_out.end_b))
    );
    chan_free(c_frames_out);
    chan_free(c_sync);
    s_chan_free(c_pdm_in);
}

void main_tile_0()
{
    assert_when_timeout();
}
