// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_CONF_H_
#define MIC_ARRAY_CONF_H_

#define MIC_ARRAY_WORD_LENGTH_SHORT 1

#if MIC_ARRAY_WORD_LENGTH_SHORT
//#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 12 // 4k FFT. Builds but there is no audio.
#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 9 // 512 FFT
#else
#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 9 // 512 FFT
#endif 
#define MIC_ARRAY_NUM_MICS 8


#endif /* MIC_ARRAY_CONF_H_ */
