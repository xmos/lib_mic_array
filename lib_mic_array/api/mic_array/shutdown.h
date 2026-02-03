// Copyright 2025-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#include "api.h"
#include "etc/xcore_compat.h"

#include <stdint.h>

C_API_START

/**
 * @brief Shut down the mic array thread(s).
 *
 * This function is called by the application to terminate the mic array threads.
 * It causes the decimator (and PDM rx if running in thread context) thread(s) to exit.
 * This is required if the mic array needs to be restarted with a different configuration
 * (a different output sampling rate for instance). After shutdown, the mic array can be initialised
 * and started with a different configuration.
 *
 * @note This function returns only after the mic array thread(s) have exited.
 *
 * @param c_frame_in chanend used to receive audio frames from the mic array.
 * This must be the same chanend passed to ma_frame_rx() or ma_frame_rx_transpose()
 * when the application receives a frame from the mic array. Shutdown is signalled to the mic array over the same chanend.
 *
 * @warning Ensure that ma_frame_rx() or ma_frame_rx_transpose() is not being called concurrently when calling ma_shutdown().
 *
 * @warning The mic array threads check for shutdown only at PDM frame boundaries.
 * If PDM data is not being received (for example, if MCLK is stopped), the threads
 * will stall and fail to detect the shutdown request. Ensure that MCLK remains active
 * during shutdown so that PDM frames continue to arrive.
 *
 */
MA_C_API
void ma_shutdown(const chanend_t c_frame_in);


C_API_END
