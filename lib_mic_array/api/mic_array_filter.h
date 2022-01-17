#pragma once


#ifdef __XC__
extern "C" {
#endif

#define STAGE1_COEF_PER_BLOCK   256

/// Stage 1 Filter

#define STAGE1_DEC_FACTOR   32
#define STAGE1_TAP_COUNT    256
#define STAGE1_WORDS        (STAGE1_TAP_COUNT)/2
#define STAGE1_TAP_BLOCKS   (((STAGE1_TAP_COUNT) + (STAGE1_COEF_PER_BLOCK-1)) / 256)

extern const uint32_t stage1_coef[STAGE1_WORDS];

/// Stage 2 Filter

#define STAGE2_DEC_FACTOR   6
#define STAGE2_TAP_COUNT    65
#define STAGE2_SHR          4

extern const int32_t stage2_coef[STAGE2_TAP_COUNT];


#ifdef __XC__
}
#endif //__XC__