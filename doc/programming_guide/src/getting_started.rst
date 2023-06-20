.. _getting_started:

Getting Started
===============

There are three models for how the mic array unit can be included in an
application. The details of how to allocate, initialize and start the mic array
will depend on the chosen model.

In order of increasing complexity, these are:

* Vanilla Model - The simplest way to include the mic array. It is usually
  sufficient but offers comparatively little flexibility with respect to
  configuration and run-time control. Using this model (mostly) means modifying
  an application's build scripts.
* Prefab Model - This model involves a little more effort from the application
  developer, including writing a couple C++ wrapper functions, but gives the
  application access to any of the defined prefab mic array components.
* General Model - Any other case. This is necessary if an application wishes to
  use a customized mic array component.

The vanilla and prefab models for integrating the mic array into your
application will be discussed in more detail below. The general model may
involve customizing or extending the classes in ``lib_mic_array`` and is beyond
the scope of this introduction.

Whichever model is chosen, the first step to integrate a mic array unit into an
application is to *identify the required hardware resources*.


Identify Resources
------------------

The key hardware resources to be identified are the *ports* and *clock blocks*
that will be used by the mic array unit.  The ports correspond to the physical
pins on which clocks and sample data will be signaled.  Clock blocks are a type
of hardware resource which can be attached to ports to coordinate the
presentation and capture of signals on physical pins.

Clock Blocks
************

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
fungible. Your application is free to use any clock block that has not already
been allocated for another purpose. The vanilla component model defaults to
using ``XS1_CLKBLK_1`` and ``XS1_CLKBLK_2``.

Ports
*****

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

XCore applications are typically compiled with an "XN" file (with a ".xn" file
extension). An XN file is an XML document which describes some information about
the device package as well as some other helpful board-related information. The
identification of your ports may have already been done for you in your XN file.
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
the port name as you will find it in your package documentation. 

In this case, either ``PORT_PDM_CLK`` or ``XS1_PORT_1G`` can be used in code to
identify this port.

Declaring Resources
*******************

Once the ports and clock blocks to be used have been identified, these
resources can be represented in code using a ``pdm_rx_resources_t`` struct. The
following is an example of declaring resources in a DDR configuration. See
:c:struct:`pdm_rx_resources_t`, :c:func:`PDM_RX_RESOURCES_SDR()` and
:c:func:`PDM_RX_RESOURCES_DDR()` for more details.

.. code-block:: c

  pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                  PORT_MCLK_IN_OUT,
                                  PORT_PDM_CLK,
                                  PORT_PDM_DATA,
                                  XS1_CLKBLK_1,
                                  XS1_CLKBLK_2);


Note that this is not necessary in applications using the vanilla model.

Other Resources
***************

In addition to ports and clock blocks, there are also several other hardware
resource types used by ``lib_mic_array`` which are worth considering. Running
out of any of these will preclude the mic array from running correctly (if at
all)

* Threads - At least one hardware thread is required to run the mic array
  component.
* Compute - The mic array unit will require a fixed number of MIPS (millions of
  instructions per second) to perform the required processing. The exact
  requirement will depend on the configuration used.
* Memory - The mic array requires a modest amount of memory for code and data.
  (see :ref:`resource_usage`).
* Chanends - At least 4 chanends must be available for signaling between
  threads/sub-components.


Vanilla Model
-------------

Mic array configuration with the vanilla model is achieved mostly through the
application's build system configuration.

In the ``/etc/vanilla`` directory of the ``lib_mic_array`` repository are a
source and header file which are not compiled with (or on the include path) of
the library. Configuring the mic array using the vanilla model means adding
those files to your *application*'s build (*not* the library target), and
defining several compile options which tell it how to behave.

Vanilla - CMake Macro
*********************

To simplify this further, a CMake macro called ``mic_array_vanilla_add()`` has
been included with the build system.

``mic_array_vanilla_add()`` takes several arguments:

* ``TARGET_NAME`` - The name of the CMake application target that the vanilla
  mode source should be added to. 
* ``MCLK_FREQ`` - The frequency of the master audio clock, in Hz. 
* ``PDM_FREQ`` - The desired frequency of the PDM clock, in Hz. 
* ``MIC_COUNT`` - The number of microphone channels to be captured. 
* ``SAMPLES_PER_FRAME`` - The size of the audio frames produced by the mic array
  unit (frames will be 2 dimensional arrays with shape
  ``(MIC_COUNT,SAMPLES_PER_FRAME)``).

Vanilla - Optional Configuration
********************************

Though not exposed by the ``mic_array_vanilla_add()`` macro, several additional
configuration options are available when using the vanilla model. These are all
configured by adding defines to the application target.

Vanilla - Initializing and Starting
***********************************

Once the configuration options have been chosen, initializing and starting the
mic array at run-time is easily achieved. Two function calls are necessary, both
are included through ``mic_array_vanilla.h`` (which was added to your include
path through your build configuration).

First, during application initialization, the function
:c:func:`ma_vanilla_init()`, which takes no arguments, must be called. This will
configure the hardware resources and install the PDM rx service as an ISR, but
will not actually start any threads or PDM capture.

Once any remaining application initialization is complete, PDM capture and
processing is started by calling :c:func:`ma_vanilla_task()`.
``ma_vanilla_task()`` is a blocking call which takes a single argument which is
the chanend that will be used to transmit audio frames to subsequent stages of
the processing pipeline. Usually the call to ``ma_vanilla_task()`` will be
placed directly in a ``par {...}`` block along with other threads to be started
on the tile.

.. note::

  Both ``ma_vanilla_init()`` and ``ma_vanilla_task()`` must be called from the
  core which will host the decimation thread.

Prefab Model
------------

The ``lib_mic_array`` library has a C++ namespace ``mic_array::prefab`` which
contains class templates for typical mic array setups using common
sub-components. The templates in the ``mic_array::prefab`` namespace hide most
of the complexity (and unneeded flexibility) from the application author, so
they can focus only on pieces they care about.

.. note::

  As of version 5.0.1, only one prefab class template,
  :cpp:class:`BasicMicArray <mic_array::prefab::BasicMicArray>`, has been 
  defined.

To configure the mic array using a prefab, you will need to add a C++ source
file to your application. NB: This will end up looking a lot like the contents
of ``mic_array_vanilla.cpp`` when you are through.

Prefab - Declare Resources
**************************

The example in this section will use ``2`` microphones in a DDR configuration
with DC offset elimination enabled, and using 128-sample frames. The resource
IDs used may differ than those required for your application.

``pdm_res`` will be used to identify the ports and clocks which will be
configured for PDM capture.

Within a C++ source file:

.. code-block:: cpp

  #include "mic_array/mic_array.h"
  ...
  #define MIC_COUNT    2    // 2 mics
  #define DCOE_ENABLE  true // DCOE on
  #define FRAME_SIZE   128  // 128 samples per frame
  ...
  pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                  PORT_MCLK_IN_OUT,
                                  PORT_PDM_CLK,
                                  PORT_PDM_DATA,
                                  MIC_ARRAY_CLK1,
                                  MIC_ARRAY_CLK2);
  ...


Prefab - Allocate MicArray
**************************

The C++ class template :cpp:class:`MicArray <mic_array::MicArray>` is central to
the mic array unit in this library. The class templates defined in the
``mic_array::prefab`` namespace each derive from ``mic_array::MicArray``.

Define and allocate the specific implementation of ``MicArray`` to be used.

.. code-block:: c++

  ...
  // Using the full name of the class could become cumbersome. Using an alias.
  using TMicArray = mic_array::prefab::BasicMicArray<
                        MIC_COUNT, FRAME_SIZE, DCOE_ENABLED>
  // Allocate mic array
  TMicArray mics = TMicArray();
  ...


Now the mic array unit has been defined and allocated. The template parameters
supplied (e.g. `MIC_COUNT` and `FRAME_SIZE`) are used to calculate the size of
any data buffers required by the mic array, and so the ``mics`` object is
self-contained, with all required buffers being statically allocated.
Additionally, class templates will ultimately allow unused features to be
optimized out at build time. For example, if DCOE is disabled, it will be
optimized out at build time so that at run time it won't even need to check
whether DCOE is enabled.

Prefab - Init and Start Functions
*********************************

Now a couple functions need to be implemented in your C++ file. In most cases
these functions will need to be callable from C or XC, and so they should not be
static, and they should be decorated with ``extern "C"`` (or the ``MA_C_API``
preprocessor macro provided by the library).

First, a function which initializes the ``MicArray`` object and configures the
port and clock block resources.  The documentation for
:cpp:class:`BasicMicArray <mic_array::prefab::BasicMicArray>` indicates any 
parts of the ``MicArray`` object that need to be initialized.

.. code-block:: c++

  #define MCLK_FREQ   24576000
  #define PDM_FREQ    3072000
  ...
  MA_C_API
  void app_init() {
    // Configure clocks and ports
    const unsigned mclk_div = mic_array_mclk_divider(MCLK_FREQ, PDM_FREQ);
    mic_array_resources_configure(&pdm_res, mclk_div);

    // Initialize the PDM rx service
    mics.PdmRx.Init(pdm_res.p_pdm_mics);
  }
  ...


``app_init()`` can be called from an XC ``main()`` during initialization.

Assuming the PDM rx service is to be run as an ISR, a second function is used to
actually start the mic array unit. This starts the PDM clock, install the ISR
and enter the decimator thread's main loop.

.. code-block:: c++

  MA_C_API
  void app_mic_array_task(chanend_t c_audio_frames) {
    mics.SetOutputChannel(c_audio_frames);

    // Start the PDM clock
    mic_array_pdm_clock_start(&pdm_res);

    mics.InstallPdmRxISR();
    mics.UnmaskPdmRxISR();

    mics.ThreadEntry();
  }


Now a call to ``app_mic_array_task()`` with the channel to send frames on can be
placed inside a ``par {...}`` block to spawn the thread.
