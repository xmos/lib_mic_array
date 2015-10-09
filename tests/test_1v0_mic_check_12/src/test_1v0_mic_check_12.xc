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

    printf("Started\n");
    int broken[8] = {0};
    int tied_to_clock[8] = {0};

    unsigned print_counter = 0;
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
#define N (1<<13)

        if((count&(N-1)) == 0){
            for(unsigned i=0;i<7;i++){
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
                if((ones[i] - N/2) <  16){
                    tied_to_clock[i]++;
                    if(tied_to_clock > 64){
                        if(!broken[i])
                            printf("%d broken - tied to clock\n", i);
                        broken[i] = 1;
                    }
                } else if((zeros[i] - N/2) <  16){
                    tied_to_clock[i]++;
                    if(tied_to_clock > 64){
                        if(!broken[i])
                            printf("%d broken - tied to clock\n", i);
                        broken[i] = 1;
                    }
                } else {
                    tied_to_clock[i]--;
                    if(tied_to_clock < 0)
                        tied_to_clock[i] = 0;
                }
               // printf("%d %8d %8d\n", i, ones[i], zeros[i]);
                ones[i]=0;
                zeros[i]=0;
                print_counter++;
                if(!(print_counter&0xff))
                        printf("Testing\n");
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
