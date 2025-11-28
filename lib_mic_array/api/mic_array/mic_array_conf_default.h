// Copyright 2015-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef _MIC_ARRAY_CONF_DEFAULT_H_
#define _MIC_ARRAY_CONF_DEFAULT_H_

/**
 * @file mic_array_conf_default.h
 * @brief Default configuration define for mic-array build time config.
 *
 * This header provides default values for all mic array configuration macros
 * if they are not defined by the application.
 *
 * To override, define in the 'mic_array_conf.h' file or as compile time define in the
 * application's CMakeLists.txt
 */

// ---------------------------------------------------------------------------
// Defaults for MIC_ARRAY_CONFIG_* macros (build-time config)
// ---------------------------------------------------------------------------

/** @brief Number of PDM microphone channels.
 * Default: 2
*/
#ifndef MIC_ARRAY_CONFIG_MIC_COUNT
#define MIC_ARRAY_CONFIG_MIC_COUNT  (2)
#endif

/** @brief Number of input mic channels - This is the width of the pdm port.
 * Default: MIC_ARRAY_CONFIG_MIC_COUNT
*/
#ifndef MIC_ARRAY_CONFIG_MIC_IN_COUNT
#define MIC_ARRAY_CONFIG_MIC_IN_COUNT   (MIC_ARRAY_CONFIG_MIC_COUNT)
#endif


/** @brief Use interrupt-driven PDM capture (1 = ISR, 0 = polling/task).
 * Default: 1 -> Use ISR
*/
#ifndef MIC_ARRAY_CONFIG_USE_PDM_ISR
#define MIC_ARRAY_CONFIG_USE_PDM_ISR    (1)
#endif

/**
 * @brief PCM samples per frame emitted by the driver.
 * Must be >= 1.
 * Default: 1
 */
#ifndef MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME
# define MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME    (1)
#else
# if ((MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME) < 1)
#  error MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME must be positive.
# endif
#endif

/** @brief Enable DC elimination on the PCM output (1 = enabled).
 * Default: 1
*/
#ifndef MIC_ARRAY_CONFIG_USE_DC_ELIMINATION
# define MIC_ARRAY_CONFIG_USE_DC_ELIMINATION    (0)
#endif

#endif // _MIC_ARRAY_CONF_DEFAULT_H_
