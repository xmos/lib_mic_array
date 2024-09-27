Microphone Array Library
========================

Summary
-------

The XMOS microphone array library is designed to allow interfacing to PDM microphones coupled with efficient decimation to user configurable output
sample rates. This library is only available for XS3 devices due to requiring the XS3 vector unit. 
It will build without errors for XS2 targets however no mic_array APIs will be available. Please see versions prior to v5.0.0 for XS2 support.

Features
........

The microphone array library has the following features:

  - 48kHz, 24kHz, 16kHz, 12kHz and 8kHz output sample rate by default (3.072MHz PDM clock)
  - Supports up to 8 microphones using only a single thread
  - Configurable PDM clock divider
  - Use the provided reference decimation filter or supply your own
  - 1 to 16 PDM microphones
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

See the `demos/` subdirectory for simple examples. Also, `sln_voice` uses this library extensively and contains
multiple examples both bare-metal and under the RTOS. See https://github.com/xmos/sln_voice/tree/develop/examples.
