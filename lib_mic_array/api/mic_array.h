// Copyright 2015-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#ifdef __XS3A__ // Only available for xcore.ai
#include "mic_array/api.h"
#else
#warning "lib_mic_array is being built using a target other than XS3 (xcore.ai). This library only supports XS3. Please use version <5.0.0 for XS2 support."  
#endif // __XS3A__
#include "mic_array/pdm_resources.h"
#include "mic_array/dc_elimination.h"
#include "mic_array/frame_transfer.h"
#include "mic_array/setup.h"

#ifdef __cplusplus
# include "mic_array/cpp/Decimator.hpp"
# include "mic_array/cpp/MicArray.hpp"
# include "mic_array/cpp/OutputHandler.hpp"
# include "mic_array/cpp/PdmRx.hpp"
# include "mic_array/cpp/Prefab.hpp"
# include "mic_array/cpp/SampleFilter.hpp"
#endif

