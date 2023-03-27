Microphone Array Library
========================

Summary
-------

The XMOS microphone array library is designed to allow interfacing to PDM 
microphones coupled with efficient decimation to user configurable output
sample rates. This library is only available for XS3 devices.

Features
........

The microphone array library has the following features:

  - 48kHz, 24kHz, 16kHz, 12kHz and 8kHz output sample rate by default (3.072MHz PDM clock)
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

Related application notes
.........................

None
