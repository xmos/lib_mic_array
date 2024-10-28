filters_default.h
=================

The filters described below are the first and second stage filters provided by
this library which are used with the 
:cpp:class:`TwoStageDecimator <mic_array::TwoStageDecimator>` class template by 
default.

Stage 1 - PDM-to-PCM Decimating FIR Filter
------------------------------------------

.. code-block::
  
  Decimation Factor:  32  
  Tap Count: 256

The first stage decimation FIR filter converts 1-bit PDM samples into 32-bit 
PCM samples and simultaneously decimates by a factor of 32.

A typical input PDM sample rate will be 3.072M samples/sec, thus the 
corresponding output sample rate will be 96k samples/sec.

The first stage filter uses 16-bit coefficients for its taps. Because 
this is a highly optimized filter targeting the VPU hardware, the first
stage filter is presently restricted to using exactly 256 filter taps.

For more information about the example first stage filter supplied with the
library, including frequency response and steps for using a custom first stage
filter, see :ref:`decimator_stages`.


.. doxygendefine:: STAGE1_DEC_FACTOR

.. doxygendefine:: STAGE1_TAP_COUNT
  
.. doxygendefine:: STAGE1_WORDS

.. doxygenvariable:: stage1_coef



Stage 2 - PCM Decimating FIR Filter
-----------------------------------

.. code-block::
  
    Decimation Factor: (configurable)
    Tap Count: (configurable)

The second stage decimation FIR filter filters and downsamples the
32-bit PCM output stream from the first stage filter into another
32-bit PCM stream with sample rate reduced by the stage 2 decimation
factor.

A typical first stage output sample rate will be 96k samples/sec, a
decimation factor of 6 (i.e. using the default stage 2 filter) will
mean a second stage output sample rate of 16k samples/sec.

The second stage filter uses 32-bit coefficients for its taps. A
complete description of the FIR implementation is outside the scope
of this documentation, but it can be found in the ```xs3_filter_fir_s32_t```
documentation of ``lib_xcore_math``.

In brief, the second stage filter coefficients are quantized to a Q1.30 
fixed-point format with input samples treated as integers. The tap outputs 
are added into a 40-bit accumulator, and an output sample is produced by 
applying a rounding arithmetic right-shift to the accumulator and then 
clipping the result to the interval ``[INT32_MAX, INT32_MIN)``.

For more information about the example second stage filter supplies with the
library, including frequency response and steps for using a custom filter,
see :ref:`decimator_stages`.


.. doxygendefine:: STAGE2_DEC_FACTOR

.. doxygendefine:: STAGE2_TAP_COUNT

.. doxygenvariable:: stage2_coef
  
.. doxygenvariable:: stage2_shr

