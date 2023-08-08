.. _vanilla_api:

Vanilla API
###########

The Vanilla API is a small optional API which greatly simplifies the process of
including a mic array unit in an xcore.ai application. Most applications that
make use of a PDM mic array will not have complicated needs from the mic array
software component beyond delivery of frames of audio data from a configurable
set of microphones at a configurable rate. This API targets that majority of 
applications. 

The prefab API requires the application developer to have at least some
minimal understanding of the objects and classes associated with the mic array
unit, and requires the developer to write some application-specific code to
configure and start the mic array. The Vanilla API (which builds on top of the
prefab model) by contrast, requires as little as two standard function calls,
and instead moves the majority of the application logic into the application's
build project.

.. note::
  
  **Why "Vanilla"?** "Vanilla" was originally meant as a generic placeholder 
  name, but no better name was ever suggested.

How It Works
============

The Vanilla API comprises two code files, ``etc/vanilla/mic_array_vanilla.cpp``
and ``etc/vanilla/mic_array_vanilla.h`` which are not compiled as part of this
library. Instead, if used, these are added to the application target's build. To
control configuration, the source file relies on a set of pre-processor macros
(added via compile flags) which determine how the mic array unit will be
instantiated.

The API is included in an application by using a CMake macro
(``mic_array_vanilla_add()``) provided in this library. The macro updates the 
application's sources, includes and compile definitions to include the API.

In the application code, two function calls are needed. First,
:c:func:`ma_vanilla_init()` is called to initialize the various mic array
sub-components, preparing for capture of PDM data. Then, to start capture the
decimation thread is started with :c:func:`ma_vanilla_task()` as entrypoint.
:c:func:`ma_vanilla_task()` takes an XCore ``chanend`` as a parameter, which
tells it where completed audio frames should be routed.

.. note::

  The Vanilla API runs the PDM rx service as an interrupt in the decimation
  thread. To run it as a separate thread (for reduced total MIPS consumption)
  one of the lower-level APIs must be used.

As with the prefab API, audio frames are extracted from the mic array unit over
a (non-streaming) channel using the :c:func:`ma_frame_rx()` or
:c:func:`ma_frame_rx_transpose()` functions.

.. note::

  The Vanilla API uses the default filters provided with this library, 
  and does not currently provide a way to override this. To use custom filters, 
  you must either use a lower-level API or modify the vanilla API.

Configuration
=============

Configuration with the Vanilla API is achieved through compile definitions. The
required definitions are provided through the ``mic_array_vanilla_add()`` macro.
There are several additional optional definitions.

mic_array_vanilla_add()
-----------------------

``mic_array_vanilla_add()`` is the CMake macro used to add the Vanilla API to an
application.

.. code-block:: cmake

  macro( mic_array_vanilla_add
            TARGET_NAME
            MCLK_FREQ 
            PDM_FREQ
            MIC_COUNT
            SAMPLES_PER_FRAME )

``TARGET_NAME`` 
  The name of the application's CMake target. It is the target the Vanilla API
  is added to.

``MCLK_FREQ``
  The known frequency, in Hz, of the application's master audio clock. A typical
  frequency is 24576000 Hz. Note that this parameter is not *configuring* the
  master audio clock. (Equivalent compile definition:
  ``MIC_ARRAY_CONFIG_MCLK_FREQ``)

``PDM_FREQ`` 
  The desired frequency, in Hz, of the PDM clock. This should be an integer
  factor of ``MCLK_FREQ`` between ``1`` and ``510``. (Equivalent compile 
  definition: ``MIC_ARRAY_CONFIG_PDM_FREQ``)

``MIC_COUNT``
  The number of PDM microphone channels to be captured. This API supports values
  of ``1`` (SDR), ``2`` (DDR), ``4`` (SDR) and ``8`` (SDR/DDR). This value must
  match the configuration (SDR/DDR) and port width of the PDM capture port. That
  is, in an SDR port configuration, ``MIC_COUNT`` must equal the capture port
  width, and in DDR port configuration, ``MIC_COUNT`` must be twice the port
  width. (Equivalent compile definition: ``MIC_ARRAY_CONFIG_MIC_COUNT``)

.. note::
    This API does not support capturing only a subset of the capture port's 
    channels, e.g. capturing only 3 channels on a 4-bit port. To accomplish this
    the prefab API should be used.

.. note::
    Though listed under Optional Configuration below, if the microphones are in
    a DDR configuration and ``MIC_COUNT`` is not ``2``, the application must 
    also define ``MIC_ARRAY_CONFIG_USE_DDR``.

``SAMPLES_PER_FRAME`` is the number of samples (for each microphone channel)
that will be delivered in each (non-overlapping) frame retrieved by
:cpp:func:`ma_frame_rx()`. A minimum value of ``1`` is supported, to deliver
samples one at a time. The larger this value, the looser the real-time
constraint on the thread receiving the mic array unit's output (while also
increasing the amount of audio data to be processed).

Optional Configuration
----------------------

These are configuration parameters that receive default values but can be
optionally overridden by an application. These can be defined in your
application's ``CMakeLists.txt`` using CMake's built-in
``target_compile_definitions()`` command.


``MIC_ARRAY_CONFIG_USE_DDR``
  Indicates whether the microphones are arranged in an SDR (``0``) or DDR 
  (``1``) configuration. An SDR configuration is one in which each port pin is
  connected to a single PDM microphone. A DDR configuration is one which each 
  port pin is connected to two PDM microphones. Defaults to ``0`` (SDR), unless
  ``MIC_ARRAY_CONFIG_MIC_COUNT`` is ``2`` in which case it defaults to ``1`` 
  (DDR).


``MIC_ARRAY_CONFIG_USE_DC_ELIMINATION``
  Indicates whether the :ref:`DC offset elimination <sample_filters>` filter 
  should be applied to the output of the decimator. Set to ``0`` to disable or
  ``1`` to enable. Defaults to ``1`` (filter on).

The next three parameters are the identifiers for hardware port resources used
by the mic array unit. They can be specified as either the identifier listed in
your device's datasheet (e.g. ``XS1_PORT_1D``) or as an alias for the port 
listed in your application's XN file (e.g. ``PORT_MCLK_IN_OUT``). For example:

.. code-block:: xml

    ...
    <Tile Number="0" Reference="tile[0]">
    ...
      <Port Location="XS1_PORT_1D"  Name="PORT_MCLK_IN_OUT"/>
    ...
    </Tile>
    ...

``MIC_ARRAY_CONFIG_PORT_MCLK``
  Identifier of the 1-bit port on which the device is receiving the master audio
  clock. Defaults to ``PORT_MLCK_IN_OUT``.


``MIC_ARRAY_CONFIG_PORT_PDM_CLK``
  Identifier of the 1-bit port on which the device will signal the PDM clock to
  the microphones. Defaults to ``PORT_PDM_CLK``.

``MIC_ARRAY_CONFIG_PORT_PDM_DATA``
  Identifier of the port on which the device will capture PDM sample data. The
  port width of this port must match the ``MIC_COUNT`` parameter given to
  ``mic_array_vanilla_add()`` and the value of ``MIC_ARRAY_CONFIG_USE_DDR``.
  Defaults to ``PORT_PDM_DATA``.

The final two parameters indicate which clock block resource(s) should be used
to generate the PDM clock and the capture clock. An xcore.ai device provides 5
hardware clock blocks for application use, identified as ``XS1_CLKBLK_1``
through ``XS1_CLKBLK_5``. The device's clock blocks are interchangeable, but if
another component of your application uses one of these defaults, you may need
to change these parameters.

``MIC_ARRAY_CONFIG_CLOCK_BLOCK_A``
  Clock block used as 'clock A' (see :ref:`getting_started`). This clock block
  is used in both SDR and DDR configurations.

``MIC_ARRAY_CONFIG_CLOCK_BLOCK_B``
  Clock block used as 'clock B' (see :ref:`getting_started`). This clock block
  is only needed in DDR configurations and is ignored (not configured) in SDR
  configurations.


Vanilla API with other Build Systems
------------------------------------

Using the Vanilla API with build systems other than CMake is simple.

* Add the file ``etc/vanilla/mic_array_vanilla.cpp`` to the application's
  source files.
* Add  ``etc/vanilla/`` (relative to repository root) to the application include 
  paths.
* Add the compile definitions for the parameters listed in the previous sections 
  (each parameter beginning with ``MIC_ARRAY_CONFIG_``) to the compile options
  for ``mic_array_vanilla.cpp``.
