
Sample Filters
==============

Following the two-stage decimation procedure in the mic array unit is an
optional post-processing stage called the sample filter.  This stage operates on
each sample emitted by the second stage decimator, one at a time, before the
samples are handed off for framing or transfer to the rest of the application's
audio pipeline.

> This is represented by the ``SampleFilter`` sub-component of the 
``mic_array::MicArray`` class template.

An application may implement its own sample filter in the form of a C++ class
which implements the ``Filter()`` function as required by ``MicArray``. See the
implementation of ``mic_array::DcoeSampleFilter`` for a simple example.

DC Offset Elimination
---------------------

The current version of this library provides a simple IIR filter called DC 
Offset Elimination (DCOE) that can be used as the sample filter.  This is a 
high-pass filter meant to ensure that each audio channel will tend towards a 
mean sample value of zero.

Enabling/Disabling DCOE
***********************

Whether the DCOE filter is enabled by default and how to enable or disable it
depends on which approach your project uses to include the mic array component
in the application.

Vanilla Model
'''''''''''''

If your project uses the vanilla model (see :ref:`vanilla_api`) to include the
mic array unit in your application, then DCOE is **enabled** by default.  To
disable DCOE your build script must add a compiler option to your application
target that sets the ``MIC_ARRAY_CONFIG_USE_DC_ELIMINATION`` preprocessor macro
to the value ``0``.

For example, in a typical application's ``CMakeLists.txt``, that may look like
the following.

::

  # Gather sources and create application target
  ...
  # Add vanilla source to application build
  mic_array_vanilla_add(my_app  ${MCLK_FREQ} ${PDM_FREQ} 
                              ${MIC_COUNT} ${FRAME_SIZE} )
  ...
  # Disable DCOE
  target_compile_definitions(my_app
      PRIVATE MIC_ARRAY_CONFIG_USE_DC_ELIMINATION=0 )


Prefab Model
''''''''''''

If your project instantiates the ``mic_array::prefab::BasicMicArray`` class
template to include the mic array unit, DC offset elimination is enabled or
disabled with the ``USE_DCOE`` boolean template parameter (there is no default).

::

  template <unsigned MIC_COUNT, unsigned FRAME_SIZE, bool USE_DCOE>
      class BasicMicArray : public ...


The sample filter chosen is based on the ``USE_DCOE`` template parameter when
the class template gets instantiated. If ``true``, ``DcoeSampleFilter`` will be
selected as the ``MicArray`` ``SampleFilter`` sub-component. Otherwise
``NopSampleFilter`` will be used.

> ``NopSampleFilter`` is a no-op filter -- it does not modify the samples given
to it and should ultimately be completely optimized out at compile time.

For example, in your application source:

::

  #include "mic_array/cpp/Prefab.hpp"
  ...
  // Controls whether DCOE is enabled
  static constexpr bool enable_dcoe = true;
  auto mics = mic_array::prefab::BasicMicArray<MICS, FRAME_SIZE, enable_dcoe>();
  ...


General Model
'''''''''''''

If your project does not use either the vanilla or prefab models to include the
mic array unit in your application, then precisely how the DCOE filter is
included may depend on the specifics of your application. In general, however,
the DCOE filter will be enabled by using ``mic_array::DcoeSampleFilter`` as the
``TSampleFilter` template parameter for the ``mic_array::MicArray`` class
template.

For example, sub-classing ``mic_array::MicArray`` as follows will enable DCOE for
any ``MicArray`` implementation deriving from that sub-class.

::

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
********************

::

    y[t] = R * y[t-1] + x[t] - x[t-1]
    R = 255.0 / 256.0

DCOE Filter Frequency Response
******************************

.. image:: dcoe_freq_response.png
