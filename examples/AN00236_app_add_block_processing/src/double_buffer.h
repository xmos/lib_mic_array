// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef __double_buffer_h__
#define __double_buffer_h__

#include "mic_array_conf.h"

#define BUF_SIZE           240

#if MIC_ARRAY_WORD_LENGTH_SHORT
#define BUFFER_TYPE int16_t
#else
#define BUFFER_TYPE int32_t
#endif


#endif