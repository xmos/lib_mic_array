.. _resource_usage:

Mic Array Resource Usage
########################

The mic array unit requires several kinds of hardware resources, including 
ports, clock blocks, chanends, hardware threads, compute time (MIPS) and memory.
Compared to previous versions of this library, the biggest advantage to the 
current version with respect to hardware resources is a greatly reduced compute
requirement. This was made possible by the introduction of the VPU in the XMOS 
XS3 architecture. The VPU can do certain operations in a single instruction 
which would take many, many instructions on previous architectures.

This page attempts to capture the requirements for each hardware type with 
relevant configurations.

.. warning::
  The usage information below applies when the Vanilla API or prefab APIs are 
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
| thread            | 1 (Vanilla)        |
|                   |                    |
|                   | 1 or 2 (prefab)    |
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
decimation thread. Two more are needed for transfering completed frames from the
mic array unit to other application components.

Threads
-------

The prefab API can run the PDM rx service either as a stand-alone thread or as
an interrupt in another thread. The Vanilla API only supports running it as an
interrupt. The Vanilla API requires only on hardware thread. The prefab API
requires 1 thread if PDM rx is used in interrupt mode, and 2 if PDM rx is a
stand-alone thread.. 

Running PDM rx as a stand-alone thread modestly reduces the mic array unit's
MIPS consumption by eliminating the context switch overhead of an interrupt. The
cost of that is one hardware thread.

.. note::

  When configured as an interrupt, PDM rx ISR is typically configured on the 
  decimation thread, but this is not a strict requirement. The PDM rx interrupt
  can be configured for any thread on the same tile as the decimation thread.
  They must be on the same tile because shared memory is used between the two
  contexts.


Compute
=======

The compute requirement of the mic array unit depends strongly on the actual
configuration being used. The compute requirement is expressed in millions of
instructions per second (MIPS) and is approximately linearly related to many
of the configuration parameters.

Each tile of an xcore.ai device has 8 hardware threads and a 5 stage pipline.
The exact calculation of how many MIPS are available to a thread is complicated,
and is, in general, affected by both the number of threads being used, as well
as the work being done by each thread.

As a rule of thumb, however, the core scheduler will offer each thread a minimum
of ``CORE_CLOCK_MHZ/8`` millions of instruction issue slots per second (~MIPS),
and no more than ``CORE_CLOCK_MHZ/5`` millions of issue slots per second, where
``CORE_CLOCK_MHZ`` is the core CPU clock rate. With a core clock rate of 600
MHz, that means that each core should expect at least 75 MIPS.

The MIPS values in the table below are estimates obtained using the demo
applications in ``demo/measure_mips``.


+------------+------+------+-------+-------+-------+-------+-------+
| PDM Freq   | S2DF | S2TC | PdmRx | 1 mic | 2 mic | 4 mic | 8 mic |
|            |      |      |       | MIPS  | MIPS  | MIPS  | MIPS  |
+============+======+======+=======+=======+=======+=======+=======+
| 3.072 MHz  |  6   |  65  | ISR   | 10.65 | 22.00 | 43.70 |  N/A  |
+------------+------+------+-------+-------+-------+-------+-------+
| 3.072 MHz  |  6   |  65  |Thread |  9.33 | 19.37 | 38.48 | 75.90 |
+------------+------+------+-------+-------+-------+-------+-------+
| 6.144 MHz  |  6   |  65  | ISR   | 21.26 | 43.89 |  TBD  |  TBD  |
+------------+------+------+-------+-------+-------+-------+-------+
| 6.144 MHz  |  6   |  65  |Thread | 18.66 | 38.73 |  TBD  |  TBD  |
+------------+------+------+-------+-------+-------+-------+-------+
| 3.072 MHz  |  3   |  65  | ISR   | 12.90 | 26.44 |  TBD  |  TBD  |
+------------+------+------+-------+-------+-------+-------+-------+
| 3.072 MHz  |  3   |  65  |Thread | 11.62 | 23.85 |  TBD  |  TBD  |
+------------+------+------+-------+-------+-------+-------+-------+
| 3.072 MHz  |  6   | 130  | ISR   | 11.17 | 23.04 |  TBD  |  TBD  |
+------------+------+------+-------+-------+-------+-------+-------+
| 3.072 MHz  |  6   | 130  |Thread |  9.86 | 20.42 |  TBD  |  TBD  |
+------------+------+------+-------+-------+-------+-------+-------+

PDM Freq
  Frequency of the PDM clock.

S2DF
  Stage 2 decimation factor. Output sample rate is ``(PDM Freq / (32 * S2DF))``.

S2TC
  Stage 2 tap count.

PdmRx
  Whether PDM capture is done in a stand-alone thread or in an ISR.

Measurements indicate that enabling or disabling the DC offset removal filter
has little effect on the MIPS usage. The selected frame size has only a slight
negative correlation with MIPS usage. 



Memory
======

The memory cost of the mic array unit has three parts: code, stack and data.
Code is the memory needed to store compiled instructions in RAM. Stack is the
memory required to store intermediate results during function calls, and data is
the memory used to store persistant objects, variables and constants.

The stack memory requirement is minimal. The code memory requirement depends on
the particular configuration, but ranges from about ``1600`` bytes in a 1 mic
configuration to about ``2000`` bytes in an 8 mic configuration.

Not included in the table is the space allocated for the first and second stage
filter coefficients. The first stage filter coefficients take a constant ``523``
bytes. The second stage filter coefficients use ``4*S2TC`` bytes, where ``S2TC``
is the stage 2 decimator tap count. The value shown in the 'data' column of the
table is the ``sizeof()`` the 
:cpp:class:`BasicMicArray <mic_array::prefab::BasicMicArray>` that is
instantiated. The table below indicates the data size for various
configurations.

+------+------+------+------+-------+--------------+
| Mics | S2DF | S2TC | SPF  | DCOE  | Data Memory  |
+======+======+======+======+=======+==============+
| 1    |  6   | 65   | 16   | On    | 504 B        |
+------+------+------+------+-------+--------------+
| 2    |  6   | 65   | 16   | On    | 968 B        |
+------+------+------+------+-------+--------------+
| 4    |  6   | 65   | 16   | On    | 1888 B       |
+------+------+------+------+-------+--------------+
| 8    |  6   | 65   | 16   | On    | 3728 B       |
+------+------+------+------+-------+--------------+
| 1    |  6   | 65   | 16   | On    | 768 B        |
+------+------+------+------+-------+--------------+
| 2    |  6   | 130  | 16   | On    | 1488 B       |
+------+------+------+------+-------+--------------+
| 1    |  6   | 130  | 16   | On    | 576 B        |
+------+------+------+------+-------+--------------+
| 2    | 12   | 65   | 16   | On    | 1112 B       |
+------+------+------+------+-------+--------------+
| 1    | 12   | 65   | 160  | On    | 1080 B       |
+------+------+------+------+-------+--------------+
| 2    |  6   | 65   | 160  | On    | 2120 B       |
+------+------+------+------+-------+--------------+
| 1    |  6   | 65   | 16   | Off   | 496 B        |
+------+------+------+------+-------+--------------+
| 2    |  6   | 65   | 16   | Off   | 948 B        |
+------+------+------+------+-------+--------------+


S2DF
  Stage 2 decimator's decimation factor.

S2TC
  Stage 2 decimator's tap count.

SPF
  Samples per frame in frames delivered by the mic array unit.

DCOE
  DC Offset Elimination