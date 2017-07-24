#include <xs1.h>
#include "mic_array.h"

void mic_array_setup_sdr(clock pdmclk,
                         in port p_mclk,
                         out port p_pdm_clk,
                         buffered in port:32 p_pdm_data,
                         int divide) {
    configure_clock_src_divide(pdmclk, p_mclk, divide/2);
    configure_port_clock_output(p_pdm_clk, pdmclk);
    configure_in_port(p_pdm_data, pdmclk);
    start_clock(pdmclk);
}

void mic_array_setup_ddr(clock pdmclk,
                         clock pdmclk6,
                         in port p_mclk,
                         out port p_pdm_clk,
                         buffered in port:32 p_pdm_data,
                         int divide) {
    configure_clock_src_divide(pdmclk, p_mclk, divide/2);
    configure_clock_src_divide(pdmclk6, p_mclk, divide/4);
    configure_port_clock_output(p_pdm_clk, pdmclk);
    configure_in_port(p_pdm_data, pdmclk6);
    // This leaves a gap of between 10 and 16 ns between the two clocks
    // That should be ok.
    asm("setc res[%0], 0xf; setc res[%1], 0xf" :: "r" (pdmclk), "r" (pdmclk6));
}
