
#include "app_config.h"
#include "mips.h"
#include "app_pll_ctrl.h"

#include "app_mic_array.h"
#include "app_i2c.h"
#include "app_i2s.h"

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

  chan c_tile_sync;
  
  par {

    on tile[0]: {

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);
      printf("Running..\n");

      printf("Initializing I2C... ");
      i2c_init();
      printf("DONE.\n");

      c_tile_sync <: 1;
    }


    on tile[1]: {

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);

      app_pll_init();
      
      unsigned ready;
      c_tile_sync :> ready;

      
      app_mic_array_setup_resources();
      app_mic_array_start();

      par {

        {
          app_mic_array_enable_isr();
          count_mips();
        }

        {
          app_i2s_task();
          printf("I2S stopped.\n");
        }

        print_mips();
      }
    }
  }

  return 0;
}

}
