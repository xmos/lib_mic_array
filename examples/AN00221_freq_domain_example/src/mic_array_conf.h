// Copyright 2016-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef MIC_ARRAY_CONF_H_
#define MIC_ARRAY_CONF_H_

#define MIC_ARRAY_WORD_LENGTH_SHORT 0 // 32 bit samples

#if MIC_ARRAY_WORD_LENGTH_SHORT
#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 9 // 512 FFT
#else
#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 9 // 512 FFT
#endif 
#define MIC_ARRAY_NUM_MICS 8

#if MIC_ARRAY_MAX_FRAME_SIZE_LOG2 > 9
#error "Max value for MIC_ARRAY_MAX_FRAME_SIZE_LOG2 is 9. There is no audio for more than 512 (1<<9) FFT points"
#endif

#endif /* MIC_ARRAY_CONF_H_ */
