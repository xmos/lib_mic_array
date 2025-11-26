.. _using_mic_array:

***********************
Using ``lib_mic_array``
***********************

.. _including_mic_array:

Including in an application
===========================

``lib_mic_array`` is intended to be used with `XCommon CMake <https://www.xmos.com/file/xcommon-cmake-documentation/?version=latest>`_
, the `XMOS` application build and dependency management system.

To use this library, include ``lib_mic_array`` in the application's ``APP_DEPENDENT_MODULES`` list in
`CMakeLists.txt`, for example:

.. code-block:: cmake

    set(APP_DEPENDENT_MODULES "lib_mic_array")

Applications should then include the ``mic_array.h`` header file.

.. _mic_array_default_model:

Default usage model
===================

The default model described in this section is the recommended approach for integrating
the mic array into an application and is suitable for most use cases.
Its constraints should be reviewed to determine whether it is compatible with the
requirements of the target application (see :ref:`mic_array_default_model_limitation`).

Typical sequence of steps required to create and use a mic-array instance
in an application:

* :ref:`Identify hardware resources <mic_array_identify_resources>`
* :ref:`Declare a struct describing the required hardware resources <mic_array_declare_resources>`
* :ref:`Initialise and start the mic array task <mic_array_init_and_start>`
* :ref:`Receive audio frames in the receiver thread <receive_pcm_frames>`
* :ref:`If required, shutdown the mic array task and optionally re-init and restart. <shutdown>`

The following sections describe the above steps in detail, followed by a :ref:`code example demonstrating
the mic array default usage model <mic_array_default_use_example>`.

.. _mic_array_identify_resources:

Identify hardware resources
---------------------------

The key hardware resources to be identified are the *ports* and *clock blocks*
that will be used by the mic array unit.  The ports correspond to the physical
pins on which clocks and sample data will be signaled.  Clock blocks are a type
of hardware resource which can be attached to ports to coordinate the
presentation and capture of signals on physical pins.

Clock blocks
^^^^^^^^^^^^

While clock blocks may be more abstract than ports, their implications for this
library are actually simpler. First, the mic array unit will need a way of
taking the audio master clock and dividing it to produce a PDM sample clock.
This can be accomplished with a clock block. This will be the clock block which
the API documentation refers to as "Clock A".

Second, if (and only if) the PDM microphones are being used in a Dual Data Rate
(DDR) configuration a second clock block will be required. In a DDR
configuration 2 microphones share a physical pin for output sample data, where
one signals on the rising edge of the PDM clock and the other signals on the
falling edge. The second clock block required in a DDR configuration is referred
to as "Clock B" in the API documentation.

Each tile on an xcore.ai device has 5 clock blocks available. In code, a clock
block is identified by its resource ID, which are given as the preprocessor
macros ``XS1_CLKBLK_1`` through ``XS1_CLKBLK_5``.

Unlike ports, which are tied to specific physical pins, clock blocks are
fungible. The application is free to use any clock block that has not already
been allocated for another purpose.

Ports
^^^^^

Three ports are needed for the mic array component. As mentioned above, ports
are physically tied to specific device pins, and so the correct ports must be
identified for correct behavior.

Note that while ports are physically tied to specific pins, this is *not* a
1-to-1 mapping. Each port has a port width (measured in bits) which is the
number of pins which comprise the port. Further, the pin mappings for different
ports *overlap*, with a single pin potentially belonging to multiple ports. When
identifying the needed ports, take care that both the pin map (see the
documentation for your xcore.ai package) and port width are correct.

The first port needed is a 1-bit port on which the audio master clock is
received. In the documentation, this is usually referred to as ``p_mclk``.

The second port needed is a 1-bit port on which the PDM clock will be signaled
to the PDM mics. This port is referred to as ``p_pdm_clk``.

The third port is that on which the PDM data is received. In an SDR
configuration, the width of this port must be greater than or equal to the
number of microphones. In a DDR configuration, twice this port width must be
greater than or equal to the number of microphones. This port is referred to as
``p_pdm_mics``.

XCORE applications are typically compiled with an "XN" file (with a ".xn" file
extension). An XN file is an XML document which describes some information about
the device package as well as some other helpful board-related information. The
identification of ports may have already been done in the XN file.
Following is a snippet from an XN file with mappings for the three ports
described above:

.. code-block:: xml

  ...
  <Tile Number="1" Reference="tile[1]">
    <!-- MIC related ports -->
    <Port Location="XS1_PORT_1G"  Name="PORT_PDM_CLK"/>
    <Port Location="XS1_PORT_1F"  Name="PORT_PDM_DATA"/>
    <!-- Audio ports -->
    <Port Location="XS1_PORT_1D"  Name="PORT_MCLK_IN_OUT"/>
    <Port Location="XS1_PORT_1C"  Name="PORT_I2S_BCLK"/>
    <Port Location="XS1_PORT_1B"  Name="PORT_I2S_LRCLK"/>
    <!-- Used for looping back clocks -->
    <Port Location="XS1_PORT_1N"  Name="PORT_NOT_IN_PACKAGE_1"/>
  </Tile>
  ...


The first 3 ports listed, ``PORT_PDM_CLK``, ``PORT_PDM_DATA`` and
``PORT_MCLK_IN_OUT`` are respectively ``p_pdm_clk``, ``p_pdm_mics`` and
``p_mclk``. The value in the ``Location`` attribute (e.g. ``XS1_PORT_1G``) is
the port name as you will find it in the package documentation.

In this case, either ``PORT_PDM_CLK`` or ``XS1_PORT_1G`` can be used in code to
identify this port.

Other Resources
^^^^^^^^^^^^^^^

In addition to ports and clock blocks, there are also several other hardware
resource types used by ``lib_mic_array`` which are worth considering. Running
out of any of these will preclude the mic array from running correctly (if at
all)

* Threads - At least one hardware thread is required to run the mic array
  component. If PDM RX service is not running in the interrupt context (MIC_ARRAY_CONFIG_USE_PDM_ISR = 0),
  a separate thread is required to run it.
* Compute - The mic array unit will require a fixed number of MIPS (millions of
  instructions per second) to perform the required processing. The exact
  requirement will depend on the configuration used.
* Memory - The mic array requires a modest amount of memory for code and data.
  (see :ref:`resource_usage`).
* Chanends - At least 4 chanends must be available for signaling between
  threads/sub-components.

.. _mic_array_declare_resources:

Declare hardware resources
--------------------------

Once the ports and clock blocks to be used have been identified, these
resources can be represented in code using a ``pdm_rx_resources_t`` struct. The
following is an example of declaring resources in a DDR configuration. See
:c:struct:`pdm_rx_resources_t`, :c:func:`PDM_RX_RESOURCES_SDR()` and
:c:func:`PDM_RX_RESOURCES_DDR()` for more details.

.. code-block:: c

  pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                  PORT_MCLK_IN,
                                  PORT_PDM_CLK,
                                  PORT_PDM_DATA,
                                  24576000,
                                  3072000,
                                  XS1_CLKBLK_1,
                                  XS1_CLKBLK_2);

.. _mic_array_init_and_start:

Initialise and start the mic array
----------------------------------

Once the resources are identified and the ``pdm_rx_resources_t`` struct is
populated, the application needs to call the mic array functions to initialise and
start the mic array task.

Call :c:func:`mic_array_init()` to initialise the mic array component.
``mic_array_init()`` accepts arguments for configuring the mic array component at run-time.

Additional configuration parameters defined in ``mic_array_conf_default.h`` specify the default
compile-time configuration of the mic array component. These can be overridden by the application in
a ``mic_array_conf.h`` file included by the application or through the application's
CMakeLists.txt. See the :ref:`mic_array_default_model_defines` section for details.

This is followed by a call to :c:func:`mic_array_start()` which starts the mic array thread(s).
``mic_array_start()`` takes a single argument -
the XCORE chanend used to transmit audio frames to subsequent stages of
the processing pipeline. Typically, the call to ``mic_array_start()`` will be
placed directly in a ``par {...}`` block along with other threads to be started
on the same tile.
``mic_array_start()`` is a blocking call that runs the mic array thread(s) until
the application signals shutdown using :c:func:`ma_shutdown()`.

.. _receive_pcm_frames:

Receive PCM frames
------------------

The application receives output PCM frames from the mic array task over an XCORE chanend. This is the other end
of the XCORE chanend passed to :c:func:`mic_array_start()`.
A call to :c:func:`ma_frame_rx()` with the chanend as an argument is typically called from another
thread to receive PCM blocks from the mic array for further processing.

.. _shutdown:

Shutdown
--------

The application can to shut down the mic array task by calling :c:func:`ma_shutdown()`.
The shutdown request is sent over the same channel end that is used by :c:func:`ma_frame_rx()`.
Therefore, the application must ensure that :c:func:`ma_frame_rx()` is not being called concurrently when
invoking :c:func:`ma_shutdown()`.

Calling :c:func:`ma_shutdown()` causes the mic-array threads to terminate
(:c:func:`mic_array_start()` returns).
:c:func:`ma_shutdown()` itself returns only after all mic-array threads have fully
terminated.
Once shut down, :c:func:`mic_array_init()` and :c:func:`mic_array_start()` can be called
again to restart the mic array.

.. note::

  Shutting down and restarting the mic array is the supported method for changing
  the output sample rate. The sample rate cannot be modified while the mic array
  is running; instead, call :c:func:`ma_shutdown()`, reconfigure the desired rate,
  and then restart the mic array.

.. _mic_array_default_use_example:

Example code
------------

The code block below shows the application ``main()`` function containing calls to the mic array functions:

.. code-block:: c

    #include <platform.h>
    #include <xs1.h>
    #include "mic_array_task.h"


    on tile[PORT_PDM_CLK_TILE_NUM] : port p_mclk = PORT_MCLK_IN_OUT;
    on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk = PORT_PDM_CLK;
    on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data = PORT_PDM_DATA;
    on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a = XS1_CLKBLK_1;
    on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b = XS1_CLKBLK_2;

    unsafe{
    void receive_from_mics(chanend c_pcm)
    {
      int32_t audio_frame[MIC_ARRAY_CONFIG_MIC_COUNT * 1]; // frame = 1 sample for each of the MIC_ARRAY_CONFIG_MIC_COUNT channels
      while(1)
      {
        ma_frame_rx(audio_frame, (chanend_t)c_pcm, MIC_ARRAY_CONFIG_MIC_COUNT, 1);
        // further processing of the pcm data...
      }
    }

    int main() {
      chan c_audio_frames;
      par {
        on tile[1]: {
          pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, 24576000, 3072000, clk_a, clk_b);

          mic_array_init(&pdm_res, null, 48000);

          par {
            mic_array_start((chanend_t) c_audio_frames);
            receive_from_mics(c_audio_frames);
          }
        }
      }
      return 0;
    }
    }

.. note::

  Code above does not demonstrate mic array shutdown.
  See the :ref:`mic array shutdown example <mic_array_app_shutdown>` for
  usage of :c:func:`ma_shutdown()`.

.. _mic_array_default_model_limitation:

Limitations of the default model
--------------------------------

The default model for using the mic array, while easiest to integrate in an application, has the
following constraints:

- Fixed supported output sampling rates:

  Only **16 kHz**, **32 kHz**, and **48 kHz** are supported.
  This is because the default decimation factors provided as part of the
  library (see :ref:`default_filters`) are predesigned for a small set of decimation
  factors and they assume a fixed input PDM frequency of **3.072 MHz**

- Only one mic array instance:

  The default model does not support multiple independent, mic array instances

- Single decimator thread:

  In the default model, the entire decimation process runs within a single hardware thread.
  For higher microphone counts, this may exceed the available compute capacity of one thread
  (see :ref:`mic array MIPS requirement <mic_array_mips_requirement>`). In general, up to
  four microphones can be accommodated within a single thread, depending on the configuration.
  Higher channel counts therefore require splitting the decimation process across multiple
  hardware threads and using lib_mic_array in a :ref:`customised <mic_array_adv_use_methods>`
  configuration. The :ref:`mic_array_par_decimator` example demonstrates a two-threaded
  decimator implementation.


- Memory usage:

  The default API incurs an additional ~6 KiB (code + data) compared to a custom
  instantiation of :cpp:class:`MicArray <mic_array::MicArray>` object.
  This overhead is primarily from wrapper code and inclusion of all
  provided filter coefficient sets, even when only a subset is used (see
  :ref:`mic_array_memory_usage`). For memory‑constrained systems a custom
  configuration might be preferable.

For custom usage refer to the advanced use methods described in :ref:`mic_array_adv_use_methods`
