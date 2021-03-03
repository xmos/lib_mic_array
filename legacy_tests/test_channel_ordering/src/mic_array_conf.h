// Copyright (c) 2015-2021, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.
#ifndef MIC_ARRAY_CONF_H_
#define MIC_ARRAY_CONF_H_

#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 0
#define MIC_ARRAY_NUM_MICS 4

#ifdef CHANNEL_REORDER_TEST
    #define MIC_ARRAY_CH0 PIN0
    #define MIC_ARRAY_CH1 PIN2
    #define MIC_ARRAY_CH2 PIN4
    #define MIC_ARRAY_CH3 PIN6
    #define MIC_ARRAY_CH4 PIN1
    #define MIC_ARRAY_CH5 PIN2
    #define MIC_ARRAY_CH6 PIN3
    #define MIC_ARRAY_CH7 PIN4
#endif

#endif /* MIC_ARRAY_CONF_H_ */
