#pragma once

#include <stdint.h>


#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif //__XC__

extern uint64_t tick_count;
extern uint64_t inst_count;

void burn_mips();
void count_mips();
void print_mips(const unsigned use_pdm_rx_isr);


#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__
