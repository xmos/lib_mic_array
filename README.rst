
:orphan:

###########################################
lib_mic_array: PDM Microphone Array Library
###########################################

:vendor: XMOS
:version: 5.4.0
:scope: General Use
:description: PDM Microphone Array Library
:category: General Purpose
:keywords: PDM, microphone
:devices: xcore.ai

********
Overview
********

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
Known Issues
************

  * PDM receive can lock-up in ISR mode when ma_frame_rx is not called isochronously after first transfer.

Also see https://github.com/xmos/lib_mic_array/issues.

**************
Required Tools
**************

  * XMOS XTC Tools: 15.3.0

*********************************
Required Libraries (dependencies)
*********************************

  * None

*************************
Related Application Notes
*************************

The following application notes use this library:

  * AN000248 - Using lib_xua with lib_mic_array

See the `examples/` subdirectory for simple usage examples.

The examples in `sln_voice <https://github.com/xmos/sln_voice/tree/develop/examples>`_ use this library extensively and contain multiple examples for both bare-metal and under FreeRTOS.

The `XVF3800 <https://www.xmos.com/xvf3800>`_ VocalFusion voice processor products also use this library.

*******
Support
*******

This package is supported by XMOS Ltd. Issues can be raised against the software at: http://www.xmos.com/support
