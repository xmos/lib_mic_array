
#include "mips.h"
#include "app_pll_ctrl.h"
#include "mic_array.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define N_MICS                    2
#define STAGE1_COEF_BLOCKS        1
#define STAGE2_DECIMATION_FACTOR  6

struct {
  ma_pdm_rx_context_t context;
  ma_pdm_buffer_t pdm_buffer[N_MICS];
  int32_t pcm_buffer[N_MICS][STAGE2_DECIMATION_FACTOR];
} mic_array_data;


// MCLK connected to pin 14 --> X1D11 --> port 1D
// MIC_CLK connected to pin 39 --> X1D22 --> port 1G
// MIC_DATA connected to pin 32 --> X1D13 --> port 1F


on tile[1]: in port p_mclk                     = XS1_PORT_1D;
on tile[1]: out port p_pdm_clk                 = XS1_PORT_1G;
on tile[1]: in buffered port:32 p_pdm_mics     = XS1_PORT_1F;
on tile[1]: clock pdmclk                       = XS1_CLKBLK_1;
on tile[1]: clock pdmclk6                      = XS1_CLKBLK_2;


#define MCLK_DIV  8


unsafe int main() {

  par {
    on tile[0]: {
      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);
      printf("Running..\n");
    }

    on tile[1]: {

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);

      app_pll_init();

      mic_array_setup_ddr((unsigned) pdmclk, (unsigned) pdmclk6, 
                          (unsigned) p_mclk, (unsigned) p_pdm_clk, 
                          (unsigned) p_pdm_mics, MCLK_DIV);

      par {
        {
          mic_array_pdm_rx_isr_init(&mic_array_data.context, 
                                    N_MICS,
                                    (unsigned) p_pdm_mics, 
                                    (int16_t*) pdm_to_pcm_coef,
                                    STAGE1_COEF_BLOCKS,
                                    STAGE2_DECIMATION_FACTOR,
                                    (ma_pdm_buffer_t*) mic_array_data.pdm_buffer,
                                    (int32_t*) mic_array_data.pcm_buffer);
          count_mips();
        }
        print_mips();

        // Note that if these are uncommented the mic array MIPS reported by `print_mips()` will
        // be incorrect, because it's just subtracting the `count_mips()` MIPS from 120.
        // It will also be wrong if the core clock rate is changed from 600 MHz

        // burn_mips();
        // burn_mips();
        // burn_mips();
        // burn_mips();
        // burn_mips();
        // burn_mips();
      }
    }
  }

  return 0;
}


