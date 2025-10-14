// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <platform.h>
#include <xscope.h>
#include <print.h>

#include "app.h"
#include <stdio.h>
#include <stdlib.h>

#ifndef USE_ISR
#error USE_ISR must be defined.
#endif

unsafe {


// We cannot be guaranteed to read less than this, and we cannot read more than
// this
#define BUFF_SIZE    256

void feed_pdm_to_app(streaming chanend c_to_app, chanend c_terminate)
{
  delay_milliseconds(100); // allow time for ISR to be setup
  printf("Starting feeding PDM now\n");
  for(int i=0; i<TEST_SZ; i++)
  {
    c_to_app <: (i+1); // start from 1
    delay_ticks(XS1_TIMER_HZ/96000);
  }
  delay_milliseconds(100);
  c_terminate <: 1; // Signal pdm receiver to terminate
}

int main()
{
  streaming chan c_to_app;
  chan c_terminate;
  chan c_fifo;

  par {
    on tile[0]: {
      feed_pdm_to_app(c_to_app, c_terminate);
    }

    on tile[0]: {
      par {
        {
#if (USE_ISR)
          app_pdm_rx_isr_setup((chanend_t) c_to_app);
#endif
          app_recv_pdm_block_task((chanend_t)c_fifo);
        }
        {
          app_fifo_to_xscope_task((chanend_t)c_fifo, (chanend_t)c_terminate);
          _Exit(0);
        }
      }
    }
  }
  return 0;
}

}
