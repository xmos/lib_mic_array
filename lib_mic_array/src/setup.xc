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

    /* start the faster capture clock */
    start_clock(pdmclk6);
    /* wait for a rising edge on the capture clock */
    partin(p_pdm_data, 4);
    /* start the slower output clock */
    start_clock(pdmclk);

    /*
     * this results in the rising edge of the capture clock
     * leading the rising edge of the output clock by one period
     * of p_mclk, which is about 40.7 ns for the typical frequency
     * of 24.576 megahertz.
     * This should fall within the data valid window.
     */
}
