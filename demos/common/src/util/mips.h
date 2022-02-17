#pragma once

#include <stdint.h>


#ifdef __XC__
extern "C" {
#endif //__XC__

extern uint64_t tick_count;
extern uint64_t inst_count;

void burn_mips();
void count_mips();
void print_mips(const unsigned use_pdm_rx_isr);


#ifdef __XC__
}
#endif //__XC__
