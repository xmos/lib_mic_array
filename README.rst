Microphone Array Library
========================

Summary
-------

The XMOS microphone array library is designed to allow interfacing to PDM microphones coupled with efficient decimation to user configurable output
sample rates.

This library is only available for XS3 devices due to requiring the XS3 vector unit. It will build without errors for XS2 targets however no mic_array APIs will be available.
Please see versions prior to v5.0.0 for XS2 support.

Features
........

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


Software version and dependencies
.................................

The CHANGELOG contains information about the current and previous versions.
For a list of direct dependencies, look for DEPENDENT_MODULES in lib_mic_array/module_build_info.

Related application notes
.........................

The following application notes use this library:

AN000248 - Using lib_xua with lib_mic_array

See the `examples/` subdirectory for simple usage examples.

The examples in `sln_voice <https://github.com/xmos/sln_voice/tree/develop/examples>`_ use this library extensively and contain multiple examples for both bare-metal and under FreeRTOS.

The `XVF3800 <https://www.xmos.com/xvf3800>`_ VocalFusion voice processor products also use this library.
