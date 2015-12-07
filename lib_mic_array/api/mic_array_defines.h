// Copyright (c) 2015, XMOS Ltd, All rights reserved
#ifndef DEFINES_H_
#define DEFINES_H_

#define NUM_MICROPHONES         8
#define MAX_NUM_CHANNELS        8
#define PDM_BUFFER_LENGTH_LOG2  (10)
#define PDM_BUFFER_LENGTH  ((1<<PDM_BUFFER_LENGTH_LOG2)*MAX_NUM_CHANNELS) / sizeof(unsigned long long)


#define MAX_DECIMATION_FACTOR 8
#define COEFS_PER_PHASE (4*12)  //must be a multiple of 2!



#endif /* DEFINES_H_ */
