// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <stdio.h>

#include <platform.h>
#include <xs1.h>

#include "app_config.h"
#include "app.h"

#if USE_BUTTONS
#include <xcore/hwtimer.h>
#endif

/*
 * For demonstrative purposes.
 * Provides basic multiplexing control (via pushbutton) over which MIC
 * data lines to output to the I2S DAC.
 */

static uint32_t selected_mic_dataline = (MIC_ARRAY_CONFIG_MIC_COUNT >> 1) - 1; // 0..7: Indicates the DDR mic pair to listen to on I2S.

#if USE_BUTTONS

#ifdef ALTERNATE_BUTTON
// NOTE: When using the alternate button, it is assumed, that an internal pull-up is needed.
const port_t btn_port = ALTERNATE_BUTTON;
#else
const port_t btn_port = PORT_BUTTONS;
#endif

uint32_t app_get_selected_mic_dataline(void)
{
    return selected_mic_dataline;
}

#if (MIC_ARRAY_TILE == 1)

void app_set_selected_mic_dataline(uint32_t dataline)
{
    selected_mic_dataline = dataline;
}

#endif

#if (MIC_ARRAY_TILE == 0)
void app_buttons_task(void)
#else
void app_buttons_task(void *app_context)
#endif
{
#if (MIC_ARRAY_TILE == 1)
  app_context_t *ctx = (app_context_t *)app_context;
#endif

  const uint32_t filter_time_ms = 200;
  const uint32_t filter_ticks = filter_time_ms * 100000;
  const int btn_mask = 0x1;
  const int btn_active_level = 0;
  int last_btn_state = 1;
  uint32_t last_state_change_ticks = 0;

  port_enable(btn_port);
#ifdef ALTERNATE_BUTTON
  port_write_control_word(btn_port, XS1_SETC_DRIVE_PULL_UP);
#endif

  while (1) {
    uint32_t current_ticks = get_reference_time();

    if (current_ticks >= last_state_change_ticks + filter_ticks) {
      int btn_state = port_in(btn_port) & btn_mask;

      if (btn_state == btn_active_level && last_btn_state != btn_state) {
        last_state_change_ticks = current_ticks;
        selected_mic_dataline = (selected_mic_dataline + 1) % (MIC_ARRAY_CONFIG_MIC_COUNT >> 1);
        printf("TILE0 DATALINE: %lu\n", selected_mic_dataline);
      }

      last_btn_state = btn_state;
    }

#if (MIC_ARRAY_TILE == 1)
    chanend_out_word(ctx->c_intertile, selected_mic_dataline);
#endif
  }
}

#endif // USE_BUTTONS
