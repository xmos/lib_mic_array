// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app_config.h"
#include "util/mips.h"
#include "device_pll_ctrl.h"
#include "mic_array/frame_transfer.h"

#include "app.h"
#include "app_common.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>



unsafe{

int main() {

  chan c_audio_frames;
  
  par {

    on tile[0]: {
      xscope_config_io(XSCOPE_IO_BASIC);
      printf("Running " APP_NAME "..\n");

      eat_audio_frames_task((chanend_t) c_audio_frames, 
                            N_MICS*SAMPLES_PER_FRAME);
    }


    on tile[1]: {

      // Force it to use xscope, never mind any config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);

      // Set up the media clocks
      device_pll_init();
      
      // Initialize the mic array
      app_init();

      par {
#if (!APP_USE_PDM_RX_ISR)
        app_pdm_rx_task();
#endif

        app_decimator_task((chanend_t) c_audio_frames);

        // The burn_mips() and the count_mips() should all consume as many MIPS as they're offered. And
        // they should all get the SAME number of MIPS.
        // print_mips() uses almost no MIPS -- we can assume it's zero.
        // So, with 600 MIPS total, 6 cores using X MIPS, 1 core using none and the mic array using Y MIPS...
        //  600 = 6*X + Y  -->  Y = 600 - 6*X

// If we're using the ISR we'll use 5 burn_mips(). Otherwise just 4. Either way the printed MIPS will
// be all the mic array work.
#if APP_USE_PDM_RX_ISR
        burn_mips();
#endif

        burn_mips();
        burn_mips();
        burn_mips();
        burn_mips();
        count_mips();
        print_mips(APP_USE_PDM_RX_ISR);
      }
    }
  }

  return 0;
}

}
