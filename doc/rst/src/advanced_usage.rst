.. _mic_array_adv_use_methods:

**********************
Advanced usage methods
**********************

There are 2 advanced usage methods for the mic array - these are:

* Prefab model - This model involves a little more effort from the application
  developer, including writing some C++ wrapper functions, but gives the
  application access to any of the defined prefab mic array components.
* General model - Any other case. This is necessary if an application wishes to
  use a customized mic array component.

The prefab model for integrating the mic array into an
application will be discussed in more detail below. The general model may
involve customizing or extending the classes in ``lib_mic_array`` and is beyond
the scope of this introduction.

Whichever model is chosen, the first step to integrate a mic array unit into an
application is to *identify the required hardware resources*. This is the same as described
in :ref:`mic_array_identify_resources`.


Prefab model
============

The ``lib_mic_array`` library has a C++ namespace ``mic_array::prefab`` which
contains a class template :cpp:class:`BasicMicArray <mic_array::prefab::BasicMicArray>`
for typical mic array setup using common sub-components. The ``BasicMicArray`` template hides most
of the complexity (and unneeded flexibility) from the application author, so
they can focus only on pieces they care about.

Configuring the mic array using a prefab requires a C++ source file to be added
to the application.

Declare resources
-----------------

The example in this section will use ``2`` microphones in a DDR configuration
with DC offset elimination enabled, and using 128-sample frames. The resource
IDs used may differ and are application dependent.

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
                                  24576000,
                                  3072000,
                                  MIC_ARRAY_CLK1,
                                  MIC_ARRAY_CLK2);
  ...


Prefab - Allocate MicArray
--------------------------

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
---------------------------------

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
