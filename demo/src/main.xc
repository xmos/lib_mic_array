
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



// Divider to bring the 24.576 MHz clock down to 3.072 MHz
#define MCLK_DIV  8

unsafe{


// MCLK connected to pin 14 --> X1D11 --> port 1D
// MIC_CLK connected to pin 39 --> X1D22 --> port 1G
// MIC_DATA connected to pin 32 --> X1D13 --> port 1F
on tile[1]: in port p_mclk                     = XS1_PORT_1D;
on tile[1]: out port p_pdm_clk                 = XS1_PORT_1G;
on tile[1]: in buffered port:32 p_pdm_mics     = XS1_PORT_1F;



static void config_clocks_ports(
    const unsigned mic_count,
    unsigned divider)
{
  if(mic_count == 4)
    divider >>= 1;
  else if(mic_count == 8)
    divider >>= 2;

  if( mic_count == 1 ){
    mic_array_setup_sdr((unsigned) MIC_ARRAY_CLK1,
                        (unsigned) p_mclk, (unsigned) p_pdm_clk, 
                        (unsigned) p_pdm_mics, divider);
  } else if( mic_count >= 2 ){
    mic_array_setup_ddr((unsigned) MIC_ARRAY_CLK1, (unsigned) MIC_ARRAY_CLK2, 
                        (unsigned) p_mclk, (unsigned) p_pdm_clk, 
                        (unsigned) p_pdm_mics, divider );
  } else {
    assert(0);
  }
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

      streaming_channel_t c_pdm_data = app_s_chan_alloc();
      assert(c_pdm_data.end_a != 0 && c_pdm_data.end_b != 0);

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);
      
      // Initialize the 
      //    app context -- just a buffer for audio between decimator and I2S
      //    decimator context, and
      //    
      app_context_init((port_t) p_pdm_mics, c_pdm_data.end_b);;

      // Set up the media clock
      app_pll_init();
      
      // Wait until tile[0] is done initializing the DAC via I2C
      unsigned ready;
      c_tile_sync :> ready;

      // Set up our clocks and ports
      config_clocks_ports(N_MICS, MCLK_DIV);

      // Start the PDM clock
      app_mic_array_start();

      //// (This is a work-around for XC's silly parallel usage rules)
      void * unsafe app_ctx;
      asm volatile("mov %0, %1" : "=r"(app_ctx) : "r"(&app_context) );



      par {
        app_decimator_task((port_t) p_pdm_mics, c_pdm_data);

#if (!APP_USE_PDM_RX_ISR)
        app_pdm_rx_task((port_t) p_pdm_mics, c_pdm_data.end_a);
#endif

#if !(MEASURE_MIPS)
        app_i2s_task( (void*) app_ctx );
#else
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
        print_mips();
#endif
      }
    }
  }

  return 0;
}

}
