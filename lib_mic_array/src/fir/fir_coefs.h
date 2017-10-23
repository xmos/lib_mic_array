// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
extern const int g_first_stage_fir_0[256];
extern const int g_first_stage_fir_1[256];
extern const int g_first_stage_fir_2[256];
extern const int fir1_debug[48];
#define FIRST_STAGE_MAX_PASSBAND_OUTPUT (2022233792)

extern const int g_second_stage_fir[8];
extern const int fir2_debug[16];

extern const int g_third_stage_div_2_fir[126];
extern const int fir3_div_2_debug[64];
#define FIR_COMPENSATOR_DIV_2 (276212818)

extern const int g_third_stage_div_4_fir[252];
extern const int fir3_div_4_debug[128];
#define FIR_COMPENSATOR_DIV_4 (285017600)

extern const int g_third_stage_div_6_fir[378];
extern const int fir3_div_6_debug[192];
#define FIR_COMPENSATOR_DIV_6 (284180149)

extern const int g_third_stage_div_8_fir[504];
extern const int fir3_div_8_debug[256];
#define FIR_COMPENSATOR_DIV_8 (285084376)

extern const int g_third_stage_div_12_fir[756];
extern const int fir3_div_12_debug[384];
#define FIR_COMPENSATOR_DIV_12 (285567922)

#define THIRD_STAGE_COEFS_PER_STAGE (32)
