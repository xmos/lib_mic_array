.. _software_structure:

******************
Software structure
******************

The core of ``lib_mic_array`` are a set of C++ class templates representing the
mic array unit and its sub-components.

The template parameters of these class templates are (mainly) used for two
different purposes. Non-type template parameters are used to specify certain
quantitative configuration values, such as the number of microphone channels.
Type template parameters, on the other hand, are used for configuring the behaviour of sub-components.

High level view
===============

At the heart of the mic array API is the
:cpp:class:`MicArray <mic_array::MicArray>` class template.

.. note::

  All classes and class templates mentioned are in the ``mic_array`` C++
  namespace unless otherwise specified. Additionally, this documentation may
  refer to class templates (e.g. ``MicArray``) with unbound template
  parameters as "classes" when doing so is unlikely to lead to confusion.

The :cpp:class:`MicArray <mic_array::MicArray>` class template looks like the
following:

.. code-block:: c++

  template <unsigned MIC_COUNT,
            class TDecimator,
            class TPdmRx,
            class TSampleFilter,
            class TOutputHandler>
  class MicArray;


Here the non-type template parameter ``MIC_COUNT`` indicates the number of
microphone channels to be captured and processed by the mic array unit. Most of
the class templates have this as a parameter.

A ``MicArray`` object comprises 4 sub-components:

.. _mic_array_subcomponents_table:

.. list-table:: MicArray sub-components
   :header-rows: 1
   :widths: 30 25 45

   * - Member Field
     - Component Class
     - Responsibility
   * - :cpp:member:`PdmRx <mic_array::MicArray::PdmRx>`
     - ``TPdmRx``
     - Capturing PDM data from a port
   * - :cpp:member:`Decimator <mic_array::MicArray::Decimator>`
     - ``TDecimator``
     - 1-, 2-, or 3-stage decimation on blocks of PDM data
   * - :cpp:member:`SampleFilter <mic_array::MicArray::SampleFilter>`
     - ``TSampleFilter``
     - Post-processing of decimated samples
   * - :cpp:member:`OutputHandler <mic_array::MicArray::OutputHandler>`
     - ``TOutputHandler``
     - Transferring audio data to subsequent pipeline stages

.. _mic_array_subcomponents_interface_requirement:

Each of the ``MicArray`` sub-components has a type that is specified as a
template parameter when the class template is instantiated. ``MicArray``
requires the class of each of its sub-components to implement a certain minimal
interface. The ``MicArray`` object interacts with its sub-components using this
interface.

.. note::

  Abstract classes are **not** used to enforce this interface contract. Instead,
  the contract is enforced (at compile time) solely in how the ``MicArray``
  object makes use of the sub-component.

The following diagram :ref:`high_level_flow` conceptually captures the flow of information through the
``MicArray`` sub-components.

.. _high_level_flow:

.. figure:: diagrams/high_level_process.drawio.png
   :align: center
   :scale: 100 %

   Mic Array High Level Process

.. note::

  ``MicArray`` does not enforce the use of an XCore port for collecting PDM
  samples or an XCore channel for transferring processed data. This is just the
  typical usage.

Mic Array / Decimator thread
----------------------------

Aside from aggregating its sub-components into a single logical entity, the
``MicArray`` class template also holds the high-level logic for capturing,
processing and coordinating movement of the audio stream data.

At the top level, ``MicArray::ThreadEntry()`` dispatches to a stage-specific
thread entry function based on the configured number of decimator stages:

.. literalinclude:: ../../../lib_mic_array/api/mic_array/cpp/MicArray.hpp
  :start-after: // MicArray::ThreadEntry()
  :end-at:     // ThreadEntry

The two-stage path is the most common configuration. Its thread loop is shown
below:

.. literalinclude:: ../../../lib_mic_array/api/mic_array/cpp/MicArray.hpp
  :start-after: // MicArray::ThreadEntryTwoStage()
  :end-at: // ThreadEntryTwoStage

The thread loops until ``OutputHandler.OutputSample()``
indicates a shutdown request. On each iteration, it:

* Requests a block of PDM sample data from the PDM rx service. This is a
  blocking call which only returns once a complete block becomes
  available.
* Passes the block of PDM sample data to the decimator to produce a single
  output sample.
* Applies a post-processing filter to the sample data.
* Passes the processed sample to the output handler to be transferred to the
  next stage of the processing pipeline. This may also be a blocking call, only
  returning once the data has been transferred.

Note that the ``MicArray`` object doesn't care how these steps are actually
implemented. For example, one output handler implementation may send samples
one at a time over a channel. Another output handler implementation may collect
samples into frames, and use a FreeRTOS queue to transfer the data to another
thread.

Sub-Component initialization
----------------------------

Each of ``MicArray``'s sub-components may have implementation-specific
configuration or initialization requirements. Each sub-component is a ``public``
member of ``MicArray`` (see :ref:`mic_array_subcomponents_table`). An application can access a
sub-component directly to perform any type-specific initialization or other
manipulation.

For example, the
:cpp:class:`ChannelFrameTransmitter <mic_array::ChannelFrameTransmitter>` output
handler class needs to know the ``chanend`` to be used for sending samples. This
can be initialized on a ``MicArray`` object ``mics`` with
``mics.OutputHandler.SetChannel(c_sample_out)``.


Sub-Components
==============

PdmRx
-----

:cpp:member:`PdmRx <mic_array::MicArray::PdmRx>`, or the PDM RX service is the
``MicArray`` sub-component responsible for capturing PDM sample data, assembling
it into blocks, and passing it along so that it can be decimated.

The ``MicArray`` class requires only that ``PdmRx`` implement ``GetPdmBlock()``,
a blocking call that returns a pointer to a block of PDM data which is ready for
further processing and ``Shutdown()``, which is called in the event of ``MicArray``
shutdown.

Generally speaking, ``PdmRx`` will derive from the
:cpp:class:`StandardPdmRxService <mic_array::StandardPdmRxService>`
class template. ``StandardPdmRxService`` encapsulates the logic of using an xCore
``port`` for capturing PDM samples one word (32 bits) at a time, and managing
two buffers where blocks of samples are collected. It also simplifies the logic
of running PDM RX as either an interrupt or as a stand-alone thread.

It uses a streaming channel to transfer PDM blocks to the
decimator. It also provides methods for installing an optimized ISR for PDM
capture.

Decimator
---------

The :cpp:member:`Decimator <mic_array::MicArray::Decimator>` sub-component
encapsulates the logic of converting blocks of PDM samples into PCM samples. The
:cpp:class:`Decimator <mic_array::Decimator>` class is a
decimator implementation that supports 1-, 2-, or 3-stage cascaded FIR
decimation.

The first stage has a fixed tap count of ``256`` and a fixed decimation factor
of ``32``. Additional stages have configurable tap counts and decimation factors.

For more details, see :ref:`decimator_stages`.

SampleFilter
------------

The :cpp:member:`SampleFilter <mic_array::MicArray::SampleFilter>` sub-component
is used for post-processing samples emitted by the decimator. Two
implementations for the sample filter sub-component are provided by this
library.

The :cpp:class:`NopSampleFilter <mic_array::NopSampleFilter>` class can be used
to effectively disable per-sample filtering on the output of the decimator. It
does nothing to the samples presented to it, and so calls to it can be optimized
out during compilation.

The :cpp:class:`DcoeSampleFilter <mic_array::DcoeSampleFilter>` class is used
for applying the DC offset elimination filter to the decimator's output. The DC
offset elimination filter is meant to ensure the sample mean for each channel
tends toward zero.

For more details, see :ref:`sample_filters`.

OutputHandler
-------------

The :cpp:member:`OutputHandler <mic_array::MicArray::OutputHandler>`
sub-component is responsible for transferring processed sample data to
subsequent processing stages.

There are two main considerations for output handlers. The first is whether
audio data should be transferred *sample-by-sample* or as *frames* containing
many samples. The second is the method of actually transferring the audio data.

The class
:cpp:class:`ChannelSampleTransmitter <mic_array::ChannelSampleTransmitter>`
sends samples one at a time to subsequent processing stages using an xCore
channel.

The :cpp:class:`FrameOutputHandler <mic_array::FrameOutputHandler>` class
collects samples into frames, and uses a frame transmitter to send the frames
once they're ready.
