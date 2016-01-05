// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef FIR_DECIMATE_H_
#define FIR_DECIMATE_H_
#include "mic_array_defines.h"

extern const int fir_1_coefs[1][COEFS_PER_PHASE];
extern const int fir_2_coefs[2][COEFS_PER_PHASE];
extern const int fir_3_coefs[3][COEFS_PER_PHASE];
extern const int fir_4_coefs[4][COEFS_PER_PHASE];
extern const int fir_5_coefs[5][COEFS_PER_PHASE];
extern const int fir_6_coefs[6][COEFS_PER_PHASE];
extern const int fir_7_coefs[7][COEFS_PER_PHASE];
extern const int fir_8_coefs[8][COEFS_PER_PHASE];

extern const int * unsafe fir_coefs[9];

#define GLUE0(x,y,z) x ## y ## z
#define GLUE(x,y,z) GLUE0(x,y,z)
#define FIR_LUT(X) (const int *  unsafe)GLUE(fir_,X,_coefs)

#endif /* FIR_DECIMATE_H_ */
