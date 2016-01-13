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

Features
........

The microphone array library has the following features:

  - 48kHz, 24kHz, 16kHz, 12kHz and 8kHz output sample rate by default, 
  - 1-16 PDM interfaces per tile,
  - Minimum of 100dBs of signal to noise for all output sample frequencies,
  - Framing,
  - Windowing and sample index bit reversal within a frame,
  - Individual microphone gain compensation,
  - DC bias removal,
  - Up to 3.072MHz input sample rate,
  - High resolution microphone specific delay lines.

Components
...........

 * PDM interface
 * four channel decimators
 * high resolution delay block

Typical Resource Usage
......................

Software version and dependencies
.................................

.. libdeps::

Related application notes
.........................

None