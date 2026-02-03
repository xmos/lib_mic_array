// Copyright 2025-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <platform.h>
#include <xscope.h>
#include <print.h>
#include <xs1.h>
#include "app.h"

unsafe {
int main()
{
  chan c_frames_out, c_sync;
  streaming chan c_pdm_in;
  par {
    on tile[1]: {
        par {
            {
                app_controller((chanend_t)c_pdm_in, (chanend_t)c_sync);
                exit(0);
            }
            app_mic((chanend_t)c_pdm_in, (chanend_t)c_frames_out);
            app_mic_interface((chanend_t)c_sync, (chanend_t)c_frames_out);
            assert_when_timeout(); // to keep the app from hanging indefinitely
        }
    }
  }
  return 0;
}
}
