// Copyright 2015-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#ifdef __XS3A__ // Only available for xcore.ai
#include "mic_array/api.h"
#endif // __XS3A__
#include "mic_array/pdm_resources.h"
#include "mic_array/dc_elimination.h"
#include "mic_array/frame_transfer.h"
#include "mic_array/shutdown.h"
#include "mic_array/setup.h"
#include "mic_array/etc/filters_default.h"
#include "mic_array/mic_array_conf_struct.h"
#include "mic_array/mic_array_task.h"
#include "mic_array/mic_array_conf_full.h"

#ifdef __cplusplus
# include "mic_array/cpp/Decimator.hpp"
# include "mic_array/cpp/MicArray.hpp"
# include "mic_array/cpp/OutputHandler.hpp"
# include "mic_array/cpp/PdmRx.hpp"
# include "mic_array/cpp/SampleFilter.hpp"
#endif

