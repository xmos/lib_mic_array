
:orphan:

###########################################
lib_mic_array: PDM microphone array library
###########################################

:vendor: XMOS
:version: 5.5.0
:scope: General Use
:description: PDM microphone array library
:category: Audio
:keywords: PDM, microphone
:devices: xcore.ai

*******
Summary
*******

The XMOS microphone array library is designed to allow interfacing to PDM microphones coupled with efficient decimation to user configurable output
sample rates.

This library is only available for XS3 devices due to requiring the XS3 vector unit. It will build without errors for XS2 targets however no mic_array APIs will be available.
Please see versions prior to v5.0.0 for XS2 support.

********
Features
********

The microphone array library has the following features:

  - 48, 32, 16 kHz output sample rates by default (3.072 MHz PDM clock)
  - 44.1, 29.4, 14.7 kHz output samples using 2.8224 MHz PDM clock
  - Other sample rates possible using custom decimation filter
  - 1 to 16 PDM microphones
  - Supports up to 8 microphones using only a single thread
  - Configurable MCLK to PDM clock divider
  - Supports both SDR and DDR microphone configurations
  - Framing with configurable frame size
  - DC offset removal
  - Extensible C++ design


************
Known issues
************

  * PDM receive can lock-up in ISR mode when ma_frame_rx is not called isochronously after first transfer.

Also see https://github.com/xmos/lib_mic_array/issues.

****************
Development repo
****************

  * `lib_mic_array <https://www.github.com/xmos/lib_mic_array>`_

**************
Required tools
**************

  * XMOS XTC Tools: 15.3.0

*********************************
Required libraries (dependencies)
*********************************

  * `lib_xcore_math <https://www.xmos.com/file/lib_xcore_math>`_

*************************
Related application notes
*************************

The following application notes use this library:

  * AN000248 - Using lib_xua with lib_mic_array

*******
Support
*******

This package is supported by XMOS Ltd. Issues can be raised against the software at: http://www.xmos.com/support
