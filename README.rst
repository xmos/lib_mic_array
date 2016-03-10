Microphone array library
========================

.. rheader::

   Microphone array library |version|

Microphone array library
------------------------

The XMOS microphone array library is designed to allow interfacing to PDM 
microphones coupled with efficient decimation to user selectable output
sample rates. Additionally, a high resolution delay can be introduced to 
each of the individual PDM microphones allowing for individual time shifts.
This library is only avaliable for XS2 devices.

Features
........

The microphone array library has the following features:

  - 48kHz, 24kHz, 16kHz, 12kHz and 8kHz output sample rate by default (3.072MHz PDM clock), 
  - 44.1kHz, 22.05kHz, 14.7kHz, 11.025kHz and 7.35kHz output sample rate by default (2.8224MHz PDM clock), 
  - 4, 8, 12 or 16 PDM interfaces per tile,
  - No less than 80dB of stop band attenuation for all output sample frequencies,
  - Configurable latency, ripple and bandwidth,
  - Framing, configurable frame size from 1 sample to 8192 samples plus 50% overlapping frames option,
  - Windowing and sample index bit reversal within a frame,
  - Individual microphone gain compensation,
  - DC offset removal,
  - Up to 3.072MHz input sample rate,
  - High resolution (2.63 microsecond) microphone specific delay lines,
  - Every task requires only a 62.5 MIPS core to run.

Components
...........

 * PDM interface,
 * Four channel decimators,
 * High resolution delay block.

Software version and dependencies
.................................

.. libdeps::

Related application notes
.........................

None
