#include <platform.h>
#include <xscope.h>
#include <xs1.h>
#include <xclib.h>

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:8  p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

int main(){

    configure_clock_src_divide(pdmclk, p_mclk, 4);
    configure_port_clock_output(p_pdm_clk, pdmclk);
    configure_in_port(p_pdm_mics, pdmclk);
    start_clock(pdmclk);
#if 0
    while(1){
        unsigned d;
        for(unsigned i=0;i<32;i++){
            unsigned v;
            p_pdm_mics :> v;
            v=v&1;
            d=d<<1;
            d|=v;
        }
        xscope_int(0, bitrev(d));
    }
#else
    unsigned d=0;
    while(1){
        for(unsigned i=0;i<32;i++)
            p_pdm_mics :> int;
        xscope_int(0, d++);
    }
#endif
    return 0;
}
