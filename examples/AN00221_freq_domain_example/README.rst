Efficient frequency domain audio processing
===========================================

Summary
-------

This example demonstrates blockwise DSP processing of audio samples received from the PDM-to-PCM decimator. The samples are received through a double buffer. The decimator can be configured to output the samples indexed in bit reversed order enabling direct processing by an FFT. The frequeny domain signals are then processed for channel 0 (low pass) and channel 1 (high pass). Subsequently the inverse FFT is performed on channel 0 and channel 1 before the samples are output over I2S to a DAC.


Software dependencies
.....................

For a list of direct dependencies, look for USED_MODULES in the Makefile.

Required hardware
.................

The example code provided with the application has been implemented
and tested on the Microphone Array Ref Design v1.

Prerequisites
.............

 * This document assumes familiarity with the XMOS xCORE architecture,
   the XMOS tool chain and the xC language. Documentation related to these
   aspects which are not specific to this application note are linked to in
   the references appendix.

 * The ``lib_mic_array`` user guide should be thoroughly read and understood.

 * For a description of XMOS related terms found in this document
   please see the XMOS Glossary [#]_.

.. [#] http://www.xmos.com/published/glossary
