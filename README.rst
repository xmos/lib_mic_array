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

The Microphone array library has the following features:

  * Configurability of:
     - Output sample rate

  * Supports:
     - up to 3.072MHz input sample rate

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