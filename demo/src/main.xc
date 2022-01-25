
#include "app_config.h"
#include "util/mips.h"
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


#define MEASURE_MIPS    0


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
        app_mic_array_task();
#if !(MEASURE_MIPS)
        app_i2s_task();
#else
        // The 5 burn_mips() and the count_mips() should all consume as many MIPS as they're offered. And
        // they should all get the SAME number of MIPS.
        // print_mips() uses almost no MIPS -- we can assume it's zero.
        // So, with 600 MIPS total, 6 cores using X MIPS, 1 core using none and the mic array using Y MIPS...
        //  600 = 6*X + Y  -->  Y = 600 - 6*X
        burn_mips();
        burn_mips();
        burn_mips();
        burn_mips();
        burn_mips();
        count_mips();
        print_mips();
#endif
      }
    }
  }

  return 0;
}

}
