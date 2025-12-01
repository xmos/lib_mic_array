.. _mic_array_adv_use_methods:

**************
Advanced usage
**************

.. note::

  Even when using a custom integration, including the library in an
  application follows the same procedure as described in :ref:`including_mic_array`.

The advanced use method requires familiarity with the mic array
:ref:`software structure <software_structure>` and a basic understanding of C++.

A custom integration involves creating a custom :cpp:class:`MicArray <mic_array::MicArray>`
object.
This allows overriding default behaviour such as decimation, PDM reception etc.

Before creating a custom object, the required hardware resources must be identified.
This process is the same as described in :ref:`mic_array_identify_resources`.

Configuring the mic array using a custom :cpp:class:`MicArray <mic_array::MicArray>`
object requires a C++ source file to be added to the application.

The following sections describe the general structure of this file.

Declare resources
-----------------

The first step is to declare a ``pdm_rx_resources_t`` struct listing the
hardware resources.

.. code-block:: c++

  pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                PORT_MCLK_IN,
                                PORT_PDM_CLK,
                                PORT_PDM_DATA,
                                MCLK_FREQ,
                                PDM_FREQ,
                                XS1_CLKBLK_1,
                                XS1_CLKBLK_2);


Construct MicArray object
-------------------------

Next, instantiate a :cpp:class:`MicArray <mic_array::MicArray>` object.
The example below creates the object with the standard component classes that are provided
by the library.
One or more of these can be overridden by a custom class, provided it implements the
:ref:`interface <mic_array_subcomponents_interface_requirement>` required by
the :cpp:class:`MicArray <mic_array::MicArray>`:

.. code-block:: c++

  using TMicArray = mic_array::MicArray<APP_N_MICS,
                          mic_array::TwoStageDecimator<APP_N_MICS,
                                              STAGE2_DEC_FACTOR_48KHZ,
                                              MIC_ARRAY_48K_STAGE_2_TAP_COUNT>,
                          mic_array::StandardPdmRxService<APP_N_MICS_IN,
                                                          APP_N_MICS,
                                                          STAGE2_DEC_FACTOR_48KHZ>,
                          typename std::conditional<APP_USE_DC_ELIMINATION,
                                              mic_array::DcoeSampleFilter<APP_N_MICS>,
                                              mic_array::NopSampleFilter<APP_N_MICS>>::type,
                          mic_array::FrameOutputHandler<APP_N_MICS,
                                                        MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                                        mic_array::ChannelFrameTransmitter>>;

  TMicArray mics;

- ``TwoStageDecimator``, ``StandardPdmRxService``, ``DcoeSampleFilter``,
  and ``FrameOutputHandler`` can all be replaced with custom classes if needed.

- Any custom class must implement the same interface expected by :cpp:class:`MicArray <mic_array::MicArray>`.

.. note::

  The ``examples/app_par_decimator`` example demonstrates replacing the standard decimator class with a
  custom multi-threaded decimator.

.. note::

  If the application requires custom decimation filters, refer to :ref:`custom_filters` to see how to do so.

Define app-callable functions
-------------------------------

Define the functions that the application will call to initialise and
run the mic array - ``app_mic_array_init()`` and ``app_mic_array_start()``:

.. code-block:: c++

  MA_C_API
  void app_mic_array_init()
  {
    mics.Decimator.Init((uint32_t*) stage1_48k_coefs, stage2_48k_coefs, stage2_48k_shift); // Replace stage1_48k_coefs with custom filter coefs if needed
    mics.PdmRx.Init(pdm_res.p_pdm_mics);
    mic_array_resources_configure(&pdm_res, MCLK_DIVIDER);
    mic_array_pdm_clock_start(&pdm_res);
  }

  DECLARE_JOB(ma_task_start_pdm, (TMicArray&));
  void ma_task_start_pdm(TMicArray& m){
    m.PdmRx.ThreadEntry();
  }

  DECLARE_JOB(ma_task_start_decimator, (TMicArray&, chanend_t));
  void ma_task_start_decimator(TMicArray& m, chanend_t c_audio_frames){
    m.ThreadEntry();
  }

  MA_C_API
  void app_mic_array_task(chanend_t c_frames_out)
  {
  #if APP_USE_PDMRX_ISR
    CLEAR_KEDI()

    mics.OutputHandler.FrameTx.SetChannel(c_frames_out);
    // Setup the ISR and enable. Then start decimator.
    mics.PdmRx.AssertOnDroppedBlock(false);
    mics.PdmRx.InstallISR();
    mics.PdmRx.UnmaskISR();
    mics.ThreadEntry();
  #else
    mics.OutputHandler.FrameTx.SetChannel(c_frames_out);
    PAR_JOBS(
        PJOB(ma_task_start_pdm, (mics)),
        PJOB(ma_task_start_decimator, (mics, c_frames_out))
      );
  #endif
  }

- ``app_mic_array_init()`` initialises the component classes and configures
  the hardware resources. Note that things like initialising the decimator with
  custom filters would be done here by passing said filters to the ``mics.Decimator.Init()``
  call.

- ``app_mic_array_task()`` starts the PDM and decimator threads or ISR-based processing.

Application main function
-------------------------

The application main function is modified to include calls to ``app_mic_array_init()``
and ``app_mic_array_task()``

.. code-block:: c++

  int main() {
    par {
      on tile[1]: {
        app_mic_array_init();
        par {
          app_mic_array_task((chanend_t) c_audio_frames);
          <... other application threads ...>
        }
      }
    }
    return 0;
  }
