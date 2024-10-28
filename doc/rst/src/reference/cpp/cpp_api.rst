#################
C++ API Reference
#################



MicArray
========

.. doxygenclass:: mic_array::MicArray
  :members:

.. raw:: latex

  \newpage




BasicMicArray
=============

.. doxygenclass:: mic_array::prefab::BasicMicArray
  :members:

.. raw:: latex

  \newpage





PdmRxService
============


.. doxygenclass:: mic_array::PdmRxService
  :members:

StandardPdmRxService
--------------------

.. doxygenstruct:: pdm_rx_isr_context_t
  :members:

.. doxygenvariable:: pdm_rx_isr_context

.. doxygenfunction:: enable_pdm_rx_isr

.. doxygenclass:: mic_array::StandardPdmRxService
  :members:

.. raw:: latex

  \newpage





TwoStageDecimator
=================

.. doxygenclass:: mic_array::TwoStageDecimator
  :members:
  
.. raw:: latex

  \newpage






SampleFilter
============


NopSampleFilter
---------------

.. doxygenclass:: mic_array::NopSampleFilter
  :members:

DcoeSampleFilter
----------------
  
.. doxygenclass:: mic_array::DcoeSampleFilter
  :members:
  
.. raw:: latex

  \newpage







OutputHandler
=================

An OutputHandler is a class which meets the requirements to be used as the 
``TOutputHandler`` template parameter of the 
:cpp:class:`MicArray <mic_array::MicArray>` class template. The basic 
requirement is that it have a method:

.. code-block::c++

  void OutputSample(int32_t sample[MIC_COUNT]);

This method is how the mic array communicates its output with the rest of the
application's audio processing pipeline. `MicArray` calls this method once for
each mic array output sample.

See :cpp:member:`MicArray::OutputHandler <mic_array::MicArray::OutputHandler>`
for more details.

FrameOutputHandler
------------------

.. doxygenclass:: mic_array::FrameOutputHandler
  :members:


ChannelFrameTransmitter
***********************
  
.. doxygenclass:: mic_array::ChannelFrameTransmitter
  :members:

.. raw:: latex

  \newpage






Misc
====

.. doxygenfunction:: mic_array::deinterleave_pdm_samples

