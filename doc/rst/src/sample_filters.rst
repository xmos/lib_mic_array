.. _sample_filters:

**************
Sample filters
**************

Following the two-stage decimation procedure is an optional post-processing
stage called the sample filter.  This stage operates on each sample emitted by
the second stage decimator, one at a time, before the samples are handed off for
framing or transfer to the rest of the application's audio pipeline.

.. note::

  This is represented by the ``SampleFilter`` sub-component of the
  :cpp:class:`MicArray <mic_array::MicArray>` class template.

An application may implement its own sample filter in the form of a C++ class
which implements the ``Filter()`` function as required by ``MicArray``. See the
implementation of :cpp:class:`DcoeSampleFilter <mic_array::DcoeSampleFilter>`
for a simple example.

DC Offset Elimination
=====================

The current version of this library provides a simple IIR filter called DC
Offset Elimination (DCOE) that can be used as the sample filter.  This is a
high-pass filter meant to ensure that each audio channel will tend towards a
mean sample value of zero.

Enabling/Disabling DCOE
-----------------------

Whether the DCOE filter is enabled by default and how to enable or disable it
depends on which approach your project uses to include the mic array component
in the application.

Default model
^^^^^^^^^^^^^

DCOE is **enabled** by default in ``mic_array_conf_default.h``. To disable, override :c:macro:`MIC_ARRAY_CONFIG_USE_DC_ELIMINATION`
through ``mic_array_conf.h`` file in the application or in the application's CMakeLists.txt.


Advanced usage model
^^^^^^^^^^^^^^^^^^^^

If the project does not use the default models to include the
mic array unit in the application, then precisely how the DCOE filter is
included may depend on the specifics of the application. In general, however,
the DCOE filter will be enabled by using
:cpp:class:`DcoeSampleFilter <mic_array::DcoeSampleFilter>` as the
``TSampleFilter`` template parameter for the
:cpp:class:`MicArray <mic_array::MicArray>` class template.

For example, sub-classing ``mic_array::MicArray`` as follows will enable DCOE
for any ``MicArray`` implementation deriving from that sub-class.

.. code-block:: c++

  #include "mic_array/cpp/MicArray.hpp"
  using namespace mic_array;
  ...
  template <unsigned MIC_COUNT, class TDecimator,
            class TPdmRx, class TOutputHandler>
  class DcoeEnabledMicArray : public MicArray<MIC_COUNT, TDecimator, TPdmRx,
                                      DcoeSampleFilter, TOutputHandler>
  {
    ...
  };


DCOE Filter Equation
--------------------

As mentioned above, the DCOE filter is a simple IIR filter given by the
following equation, where ``x[t]`` and ``x[t-1]`` are the current and previous
input sample values respectively, and ``y[t]`` and ``y[t-1]`` are the current
and previous output sample values respectively.

::

    R = 252.0 / 256.0
    y[t] = R * y[t-1] + x[t] - x[t-1]


DCOE Filter Frequency Response
------------------------------

The plot below indicates the frequency response of DCOE filter :ref:`freq_response_dcoe`.

.. _freq_response_dcoe:

.. figure:: plots/dcoe_freq_response.png
   :align: center
   :scale: 100 %

   DCOE filter frequency response
