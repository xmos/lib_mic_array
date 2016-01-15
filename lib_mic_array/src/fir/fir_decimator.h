// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef FIR_DECIMATOR_H_
#include <limits.h>
#define FIR_DECIMATOR_H_
#define FIRST_STAGE_SCALE_FACTOR (1.1642155076146248)
extern int fir1_debug[48];

#define SECOND_STAGE_SCALE_FACTOR (1.0000000000000002)
extern int fir2_debug[16];

#define DIV_12_SCALE_FACTOR  (1.8951481905185792)
#define DECIMATION_FACTOR_DIV_12 (12)
#define FIR_COMPENSATOR_DIV_12 ((int)((double)(INT_MAX>>4) * FIRST_STAGE_SCALE_FACTOR * SECOND_STAGE_SCALE_FACTOR * DIV_12_SCALE_FACTOR))
extern const int g_third_stage_div_12_fir[756];
extern int fir3_div_12_debug[384];

#define DIV_2_SCALE_FACTOR  (1.8241973648029566)
#define DECIMATION_FACTOR_DIV_2 (2)
#define FIR_COMPENSATOR_DIV_2 ((int)((double)(INT_MAX>>4) * FIRST_STAGE_SCALE_FACTOR * SECOND_STAGE_SCALE_FACTOR * DIV_2_SCALE_FACTOR))
extern const int g_third_stage_div_2_fir[126];
extern int fir3_div_2_debug[64];

#define DIV_4_SCALE_FACTOR  (1.8916012627878314)
#define DECIMATION_FACTOR_DIV_4 (4)
#define FIR_COMPENSATOR_DIV_4 ((int)((double)(INT_MAX>>4) * FIRST_STAGE_SCALE_FACTOR * SECOND_STAGE_SCALE_FACTOR * DIV_4_SCALE_FACTOR))
extern const int g_third_stage_div_4_fir[252];
extern int fir3_div_4_debug[128];

#define DIV_6_SCALE_FACTOR  (1.8864402170866945)
#define DECIMATION_FACTOR_DIV_6 (6)
#define FIR_COMPENSATOR_DIV_6 ((int)((double)(INT_MAX>>4) * FIRST_STAGE_SCALE_FACTOR * SECOND_STAGE_SCALE_FACTOR * DIV_6_SCALE_FACTOR))
extern const int g_third_stage_div_6_fir[378];
extern int fir3_div_6_debug[192];

#define DIV_8_SCALE_FACTOR  (1.8921195550834473)
#define DECIMATION_FACTOR_DIV_8 (8)
#define FIR_COMPENSATOR_DIV_8 ((int)((double)(INT_MAX>>4) * FIRST_STAGE_SCALE_FACTOR * SECOND_STAGE_SCALE_FACTOR * DIV_8_SCALE_FACTOR))
extern const int g_third_stage_div_8_fir[504];
extern int fir3_div_8_debug[256];

#define THIRD_STAGE_COEFS_PER_STAGE (32)
#define THIRD_STAGE_COEFS_PER_ROW   (63)
#endif /* FIR_DECIMATOR_H_ */
