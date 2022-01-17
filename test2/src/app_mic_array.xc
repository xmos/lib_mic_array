
#include "app_config.h"
#include "app_mic_array.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>

#include <stdint.h>
#include <stdlib.h>
#include <assert.h>



struct {
  // Mic array thread context
  ma_pdm_rx_context_t context;

  // 256 samples (256 bits) per microphone per stage 1 coefficient block
  uint32_t pdm_buffer[N_MICS][STAGE1_TAP_BLOCKS][8];
  int32_t pcm_buffer[N_MICS][STAGE2_DEC_FACTOR];
} mic_array_data;


#define MIC_ARRAY_CLK1  XS1_CLKBLK_1
#define MIC_ARRAY_CLK2  XS1_CLKBLK_2

// MCLK connected to pin 14 --> X1D11 --> port 1D
// MIC_CLK connected to pin 39 --> X1D22 --> port 1G
// MIC_DATA connected to pin 32 --> X1D13 --> port 1F
on tile[1]: in port p_mclk                     = XS1_PORT_1D;
on tile[1]: out port p_pdm_clk                 = XS1_PORT_1G;
on tile[1]: in buffered port:32 p_pdm_mics     = XS1_PORT_1F;


// Divider to bring the 24.576 MHz clock down to 3.072 MHz
#define MCLK_DIV  8

unsafe {

void app_mic_array_setup_resources()
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


void app_mic_array_enable_isr()
{

  proc_pcm_init();
  mic_array_pdm_rx_isr_init(&mic_array_data.context, 
                            N_MICS,
                            (unsigned) p_pdm_mics, 
                            (uint32_t*) stage1_coef,
                            STAGE1_TAP_BLOCKS,
                            STAGE2_DEC_FACTOR,
                            &mic_array_data.pdm_buffer[0][0][0],
                            &mic_array_data.pcm_buffer[0][0]);
}

}