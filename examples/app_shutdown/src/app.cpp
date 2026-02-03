// Copyright 2025-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>
#include <string.h>
#include <platform.h>

#include <xcore/channel.h>
#include <xcore/hwtimer.h>
#include <xcore/channel_streaming.h>
#include "app.h"
#include "app_config.h"
#include <print.h>
#include <xcore/port.h>


pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                PORT_MCLK_IN,
                                PORT_PDM_CLK,
                                PORT_PDM_DATA,
                                MCLK_48,
                                PDM_FREQ,
                                XS1_CLKBLK_1,
                                XS1_CLKBLK_2);

void app_mic(chanend_t c_frames_out)
{
    while(1) {
        int fs = chan_in_word(c_frames_out);
        mic_array_init(&pdm_res, NULL, fs);
        mic_array_start(c_frames_out);
    }
}

void button_task(chanend_t c_sync)
{
    port_t my_port = PORT_GPI;
    port_enable(my_port);
    bool init = true;
    unsigned current_state, prev_state;
    unsigned debounce_delay_ms = 50;
    unsigned debounce_delay_ticks = debounce_delay_ms * XS1_TIMER_KHZ;

    hwtimer_t tmr = hwtimer_alloc();
    while(1)
    {
        current_state = ((port_in(my_port) & (1<<5))) >> 5; // get the 'button' bit from the port read value
        if(init) {
            prev_state = current_state;
            init = false;
        }
        else {
            if(prev_state != current_state)
            {
                if((prev_state == 1) && (current_state == 0))
                {
                    // button pressed
                    chan_out_word(c_sync, 1);
                }
                hwtimer_delay(tmr, debounce_delay_ticks);
            }
            prev_state = current_state;
        }
    }
    hwtimer_free(tmr);
}
