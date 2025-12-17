.. _resource_usage:

**************
Resource usage
**************

The mic array unit requires several kinds of hardware resources, including
ports, clock blocks, chanends, hardware threads, compute time (MIPS) and memory.

This page attempts to capture the requirements for each hardware type with
relevant configurations.

.. warning::
  The usage information below applies when the default usage model is
  used. Resource usage in an application which uses custom mic array
  sub-components will depend crucially on the specifics of the customization.

Discrete Resources
==================

+-------------------+--------------------+
| Resource          | Count              |
+===================+====================+
| port              | 3                  |
+-------------------+--------------------+
| clock block       | 1 (SDR)            |
|                   |                    |
|                   | 2 (DDR)            |
+-------------------+--------------------+
| chanend           | 4                  |
|                   |                    |
+-------------------+--------------------+
| thread            | 1 or 2             |
|                   |                    |
+-------------------+--------------------+

Ports
-----

In all configurations, the mic array unit requires 3 of the xcore.ai device's
hardware ports. Two of these ports (for the master audio clock and PDM clock)
must be 1-bit ports. The third (PDM capture port) can be 1-, 4- or 8-bit,
depending on the microphone count and SDR/DDR configuration.

Clock Blocks
------------

In applications which use an SDR microphone configuration, the mic array unit
requires 1 of the xcore.ai device's 5 clock blocks. This clock block is used
both to generate the PDM clock from the master audio clock and as the PDM
capture clock.

In applications which use a DDR microphone configuration, the mic array unit
requires 2 of the xcore.ai device's 5 clock blocks. One clock is used to
generate the PDM clock from the master audio clock, and the other is used as the
PDM capture clock (which must operate at different rates in a DDR
configuration).

Chanends
--------

Chanends are a hardware resource which allow threads (possibly running on
different tiles) to communicate over channels. The mic array unit requires 4
chanends. Two are used for communication between the PDM rx service and the
decimation thread. Two more are needed for transferring completed frames from the
mic array unit to other application components.

Threads
-------

The PDM rx service can run either as a stand-alone thread or as an interrupt within the decimator thread.
Accordingly, the mic array requires one thread when the PDM rx service runs in interrupt mode,
and two threads when it runs as a stand-alone thread.

Running PDM rx as a stand-alone thread modestly reduces the mic array unit's
MIPS consumption by eliminating the context switch overhead of an interrupt. The
cost of that is one hardware thread.

.. note::

  When configured as an interrupt, PDM rx ISR is typically configured on the
  decimation thread, but this is not a strict requirement. The PDM rx interrupt
  can be configured for any thread **on the same tile** as the decimation thread.
  They must be on the same tile because shared memory is used between the two
  contexts.


.. _mic_array_mips_requirement:

Compute
=======

The compute requirement of the mic array unit depends strongly on the actual
configuration being used. The compute requirement is expressed in millions of
instructions per second (MIPS) and is approximately linearly related to many
of the configuration parameters.

Each tile of an xcore.ai device has 8 hardware threads and a 5 stage pipeline.
The exact calculation of how many MIPS are available to a thread is complicated,
and is, in general, affected by both the number of threads being used, as well
as the work being done by each thread.

As a rule of thumb, however, the core scheduler will offer each thread a minimum
of `CORE_CLOCK_MHZ/8` millions of instruction issue slots per second (~MIPS),
and no more than `CORE_CLOCK_MHZ/5` millions of issue slots per second, where
`CORE_CLOCK_MHZ` is the core CPU clock rate (specified as ``SystemFrequency`` in the XN file).
With a core clock rate of 600 MHz, that means that each core should expect at least 75 MIPS.

Table :ref:`mic_array_mips` shows the mic array MIPS by profiling an application that includes the
mic array. The application used to generate the MIPS numbers runs the :ref:`default <mic_array_default_model>` mic
array API (so the decimator running in a single hardware thread) with all defines set to their default values as listed
in :ref:`mic_array_default_model_defines` except for ``MIC_ARRAY_CONFIG_MIC_COUNT``
and ``MIC_ARRAY_CONFIG_USE_PDM_ISR``. These two (along with the output sampling rate) are varied to build the
different configurations that are profiled.

.. include:: ../../../tests/signal/profile/mic_array_mips_table.rst

.. note::

  The MIPS numbers scale approximately linearly with the number of microphones. Although the table lists values only
  for the 1- and 2-mic configurations, these results can be extrapolated to estimate MIPS for configurations with a
  higher microphone count. If a given configuration cannot be accommodated within a single hardware thread, the
  decimator can be split across multiple threads to distribute the compute load. This approach is not supported by the
  :ref:`default <mic_array_default_model>` mic array API. An example of a custom multi-threaded decimator implementation
  can be found in :ref:`mic_array_par_decimator`.



Memory
======

The memory cost of the mic array unit has three parts: code, stack and data.
Code is the memory needed to store compiled instructions in RAM. Stack is the
memory required to store intermediate results during function calls, and data is
the memory used to store persistent objects, variables and constants.

Table :ref:`mic_array_memory_usage` reports the memory usage of two minimal applications that include the mic array:
one using the :ref:`default <mic_array_default_model>` mic array API and another using a :ref:`custom <mic_array_adv_use_methods>`
configuration created by instantiating a :cpp:class:`MicArray <mic_array::MicArray>` object.

Both applications are built for **1 or 2 microphones** with a **16 kHz output sample rate**, with the other
compile-time parameters set to their default values as defined in :ref:`mic_array_default_model_defines`.

Memory for higher microphone counts can be extrapolated from the 1- and 2-mic numbers.

Across different sampling rates, memory usage with the default API remains unchanged
since the default API compiles all the decimation filters included in the library.
For custom usage, the data memory across different sampling rates varies depending on the
:ref:`decimation filters <decimator_stages>` included.

.. include:: ../../../tests/signal/profile/mic_array_memory_table.rst

.. note::

  The default API requires more memory than the custom configuration.
  The additional code memory comes from the wrapper and abstraction code included in the default API.
  The increased data memory results from the inclusion of filter coefficients
  for all filters provided by the library, whereas the custom build includes only the coefficients
  required by the specific MicArray instance.

.. note::

  A minimal empty application (no mic array) occupies ~4.6 KiB
  (Stack: 356 B, Code: 3754 B, Data: 542 B). Subtract this baseline
  from the reported totals to isolate mic array overhead.
