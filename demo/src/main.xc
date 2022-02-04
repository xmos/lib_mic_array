
#include "app_config.h"
#include "util/mips.h"
#include "app_pll_ctrl.h"

#include "app.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>


// Set this to 1 to measure MIPS consumption by the mic array
// (Note: measuring MIPS will disable I2S)
#define MEASURE_MIPS    0



unsafe{



// MCLK connected to pin 14 --> X1D11 --> port 1D
// MIC_CLK connected to pin 39 --> X1D22 --> port 1G
// MIC_DATA connected to pin 32 --> X1D13 --> port 1F
on tile[1]: in port p_mclk                     = XS1_PORT_1D;
on tile[1]: out port p_pdm_clk                 = XS1_PORT_1G;
on tile[1]: in buffered port:32 p_pdm_mics     = XS1_PORT_1F;


// Divider to bring the 24.576 MHz clock down to 3.072 MHz
#define MCLK_DIV  8

static void config_clocks_ports()
{
  unsigned div = MCLK_DIV;
  if(N_MICS == 4)
    div >>= 1;
  else if(N_MICS == 8)
    div >>= 2;

  if( N_MICS == 1 ){
    mic_array_setup_sdr((unsigned) MIC_ARRAY_CLK1,
                        (unsigned) p_mclk, (unsigned) p_pdm_clk, 
                        (unsigned) p_pdm_mics, div);
  } else if( N_MICS >= 2 ){
    mic_array_setup_ddr((unsigned) MIC_ARRAY_CLK1, (unsigned) MIC_ARRAY_CLK2, 
                        (unsigned) p_mclk, (unsigned) p_pdm_clk, 
                        (unsigned) p_pdm_mics, div );
  } else {
    assert(0);
  }
}


static void app_mic_array_setup()
{
  // Set up our clocks and ports
  config_clocks_ports();

  chanend_t c_pdm = ma_pdm_rx_isr_init( (unsigned) p_pdm_mics,
                      (uint32_t*) &ma_data.stage1.pdm_buffers[0],
                      (uint32_t*) &ma_data.stage1.pdm_buffers[1],
                      N_MICS * STAGE2_DEC_FACTOR);

  app_pdm_filter_context_init( c_pdm );

  ma_pdm_rx_isr_enable( (port_t) p_pdm_mics );
}




static void app_mic_array_start()
{
  if( N_MICS == 1 ){
    mic_array_start_sdr((unsigned) MIC_ARRAY_CLK1);
  } else if( N_MICS >= 2 ){
    mic_array_start_ddr((unsigned) MIC_ARRAY_CLK1, 
                        (unsigned) MIC_ARRAY_CLK2, 
                        (unsigned) p_pdm_mics );
  }
}





int main() {

  chan c_tile_sync;
  
  par {

    on tile[0]: {

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);
      printf("Running..\n");

      printf("Initializing I2C... ");
      app_i2c_init();
      printf("DONE.\n");

      c_tile_sync <: 1;
    }


    on tile[1]: {

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);
      
      // The app context comprises objects shared between the mic array
      // and I2S components for buffering output audio 
      app_context_init();

      // Set up the media clock
      app_pll_init();
      
      // Wait until tile[0] is done initializing I2C
      unsigned ready;
      c_tile_sync :> ready;

      //// (This is a work-around for XC's draconian, unnecessary parallel usage rules)
      void * unsafe app_ctx;
      asm volatile("mov %0, %1" : "=r"(app_ctx) : "r"(&app_context) );

      par {
        {
          // Set up the mic array component
          app_mic_array_setup();
          // Start the PDM clock
          app_mic_array_start();

          ma_pdm_filter_task( &pdm_filter_context, &app_context );
        }
#if !(MEASURE_MIPS)
        app_i2s_task( (void*) app_ctx );
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
