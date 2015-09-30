#include <platform.h>
#include <xs1.h>
#include <stdio.h>

on tile[0]: in port p_pdm_clk             = XS1_PORT_1E;
on tile[0]: in port p_pdm_mics            = XS1_PORT_8B;
on tile[0]: in port p_mclk                = XS1_PORT_1F;
on tile[0]: clock mclk                    = XS1_CLKBLK_1;
on tile[0]: clock pdmclk                  = XS1_CLKBLK_2;

static void pdm_interface(in port p_pdm_mics){
    unsigned v;
    unsigned ones[8] = {0};
    unsigned zeros[8] = {0};
    unsigned count = 0;

    int broken[8] = {0};

    for(unsigned i=0;i<0xfffff;i++)
        p_pdm_mics:> v;

    while(1){
        for(unsigned i=0;i<8;i++){
            unsigned d = v&1;
            v=v>>1;
            if(d)
                ones[i]++;
            else
                zeros[i]++;
        }
        count++;
#define N 4096

        if((count&(N-1)) == 0){
            for(unsigned i=0;i<8;i++){
                if(ones[i] == N){
                    if(!broken[i])
                        printf("%d broken - tied high\n", i);
                    broken[i] = 1;
                }
                if(ones[i] == 0){
                    if(!broken[i])
                        printf("%d broken - tied low\n", i);
                    broken[i] = 1;
                }
                if(zeros[i] == N){
                    if(!broken[i])
                        printf("%d broken - tied low\n", i);
                    broken[i] = 1;
                }
                if(zeros[i] == 0){
                    if(!broken[i])
                        printf("%d broken - tied high\n", i);
                    broken[i] = 1;
                }
                if((ones[i] - N/2) <  32){
                    if(!broken[i])
                        printf("%d broken - tied to clock\n", i);
                    broken[i] = 1;
                }
                if((zeros[i] - N/2) <  32){
                    if(!broken[i])
                        printf("%d broken - tied to clock\n", i);
                    broken[i] = 1;
                }
                ones[i]=0;
                zeros[i]=0;
            }
        }
        p_pdm_mics:> v;
        delay_ticks(v); //add pseudo random sampling
    }
}

int main(){

    par{
        on tile[0]: {
            configure_clock_src(mclk, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 8);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk);
            start_clock(pdmclk);
            par{
                pdm_interface(p_pdm_mics);
            }
        }
    }
    return 0;
}
