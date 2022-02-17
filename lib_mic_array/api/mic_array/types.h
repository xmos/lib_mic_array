#pragma once

// Some types are defined here to avoid circular header dependencies.


#include "xcore_compat.h"

#ifdef __XC__
extern "C" {
#endif


#ifndef MA_DECIMATOR_OUTPUT_TYPE
#define MA_DECIMATOR_OUTPUT_TYPE  chanend_t
#endif

typedef MA_DECIMATOR_OUTPUT_TYPE ma_dec_output_t;




#ifdef __XC__
}
#endif //__XC__