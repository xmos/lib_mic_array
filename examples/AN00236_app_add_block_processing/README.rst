.. |I2S| replace:: I\ :sup:`2`\ S
.. |I2C| replace:: I\ :sup:`2`\ C

Add Block Processing of audio samples
=====================================

.. version:: 1.0.0

Summary
-------

This example is based on `AN00218: High Resolution Delay and Sum <https://www.xmos.com/support/appnotes/AN00218>`_.
It adds the ability for block processing of audio data. This is useful e.g. for keyword recognition algorithms.
sample rate (16 kHz, 48 kHz) and sample resolution (16 bit, 32 bit) are configurable.

This document is a supplementary to AN00218.

Required tools and libraries
............................

.. appdeps::

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


