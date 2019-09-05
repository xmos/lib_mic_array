// Copyright (c) 2015-2019, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_CONF_H_
#define MIC_ARRAY_CONF_H_


#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 8     // Don't care for mic_dual, used FRAME_SIZE
#define MIC_ARRAY_NUM_MICS 4                // Don't care for mic_dual, always 2

#define MIC_DECIMATION_FACTOR 6             // Don't care for mic_dual, always 6
#define MIC_FRAME_BUFFERS  2                // Don't care - Defined within mic_dual.xc
#define MIC_CHANNELS 4                      // Don't care for mic_dual, always 2
#define MIC_DECIMATORS 1                    // Don't care for mic_dual
#ifndef MIC_ARRAY_FRAME_SIZE
#define MIC_ARRAY_FRAME_SIZE 240            // We *do* care about this in mic_dual
#endif

#endif /* MIC_ARRAY_CONF_H_ */
