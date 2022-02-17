#pragma once

#include "mic_array.h"


#ifdef __XC__
extern "C" {
#endif

void mic_array_simple_init(
    pdm_rx_resources_t* pdm_res);

void mic_array_simple_decimator_task(
    pdm_rx_resources_t* pdm_res,
    chanend_t c_decimator_out);

    
#ifdef __XC__
}
#endif