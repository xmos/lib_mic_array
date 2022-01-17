
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
#include <assert.h>

// Number of microphones to use
#define N_MICS                    1
// Number of stage1 coefficient blocks
#define STAGE1_COEF_BLOCKS        1
// Decimation factor for second stage (6:  96kHz -> 16kHz)
#define STAGE2_DECIMATION_FACTOR  6

struct {
  // Mic array thread context
  ma_pdm_rx_context_t context;

  // 256 samples (256 bits) per microphone per stage 1 coefficient block
  uint32_t pdm_buffer[N_MICS][STAGE1_COEF_BLOCKS][8];
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

// Divider to bring the 24.576 MHz clock down to 3.072 MHz
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

      unsigned div = MCLK_DIV;
      if(N_MICS == 4)
        div >>= 1;
      else if(N_MICS == 8)
        div >>= 2;

      if( N_MICS == 1 ){
        mic_array_setup_sdr((unsigned) pdmclk,
                            (unsigned) p_mclk, (unsigned) p_pdm_clk, 
                            (unsigned) p_pdm_mics, div);
      } else if( N_MICS >= 2 ){
        mic_array_setup_ddr((unsigned) pdmclk, (unsigned) pdmclk6, 
                            (unsigned) p_mclk, (unsigned) p_pdm_clk, 
                            (unsigned) p_pdm_mics, div );
      } else {
        assert(0);
      }

      par {
#if !(USE_C_VERSION)
        {
          proc_pcm_init();
          mic_array_pdm_rx_isr_init(&mic_array_data.context, 
                                    N_MICS,
                                    (unsigned) p_pdm_mics, 
                                    (int16_t*) pdm_to_pcm_coef,
                                    STAGE1_COEF_BLOCKS,
                                    STAGE2_DECIMATION_FACTOR,
                                    &mic_array_data.pdm_buffer[0][0][0],
                                    &mic_array_data.pcm_buffer[0][0]);
          count_mips();
        }
#else // !USE_C_VERSION
        {
          pdm_rx_config_t config;
          config.mic_count = N_MICS;
          config.phase2 = 0;
          config.stage1.p_pdm_mics = (unsigned) p_pdm_mics;
          config.stage1.fir_coef = (int16_t*) pdm_to_pcm_coef;
          config.stage1.pdm_coef_blocks = STAGE1_COEF_BLOCKS;
          config.stage1.pdm_buffer = (unsigned*) mic_array_data.pdm_buffer;
          config.stage2.decimation_factor = STAGE2_DECIMATION_FACTOR;
          config.stage2.pcm_vector = (int32_t*) mic_array_data.pcm_buffer;

          proc_pcm_init();
          pdm_rx(&config);
        }

        count_mips();
        burn_mips();
        burn_mips();
        burn_mips();
        burn_mips();
        // burn_mips();
#endif
        print_mips();
      }
    }
  }

  return 0;
}


