.. _custom_filters:

*************************
Custom decimation filters
*************************

In the :cpp:class:`TwoStageDecimator <mic_array::TwoStageDecimator>`, the tap count and decimation factor
for the first stage decimator are fixed to ``256`` and ``32`` respectively, as described in :ref:`decimator_stage_1`.

These parameters cannot be changed without implementing a custom decimator, which is outside the scope of this document.

However, both the first-stage and second-stage filter coefficients may be
replaced, and the second-stage decimation factor and tap count may be freely
modified by running the mic array component with custom filters. This is described in the following sections.

.. _designing_custom_filters:

Designing a custom filter
=========================

A filter design script is provided in ``python/filter_design/design_filter.py``.
The script contains functions to generate the filters currently provided as part
of ``lib_mic_array`` and save them as ``.pkl`` files. Using these functions as
a guide, the script can be extended to generate custom filters tailored to the
application's needs.

Note that in :cpp:class:`TwoStageDecimator <mic_array::TwoStageDecimator>`,
both the first and second stage filters are implemented
using fixed-point arithmetic, which requires the coefficients to be presented
in a specific format.
The helper scripts ``python/stage1.py`` and ``python/stage2.py`` generate
the correctly quantized and interleaved coefficient arrays required by the
library.

After generating a ``.pkl`` file, the helper scripts ``stage1.py`` and
``stage2.py`` can be used to format the first and second stage filters,
respectively, into the fixed-point C arrays required by the library.

Alternatively, the ``combined.py`` script can process both the first and second
stage filters in one step. When executed, ``stage1.py``, ``stage2.py``, and
``combined.py`` print the filter coefficients as C-style arrays, along with
filter-related defines such as tap count, decimation factor, etc., as
``#define`` macros on stdout.

The scripts can also be run with the ``--file-prefix <prefix>`` (or
``-fp <prefix>``) option. In this mode, all arrays and defines are written into
a header file (``<prefix>.h``), which can be included in the application.

Running ``python combined.py --help`` from the ``python`` directory shows full
usage instructions.

From the ``python`` directory, the workflow is typically:

.. code-block:: console

    python filter_design/design_filter.py                     # generates the
                                                              # .pkl files
    python combined.py <custom_filter.pkl> -fp <prefix>      # converts the
                                                              # .pkl file to C
                                                              # arrays for stage
                                                              # 1 and 2, and
                                                              # writes to
                                                              # <prefix>.h


.. _using_custom_filters:

Using custom filters
====================

When using the :cpp:class:`TwoStageDecimator <mic_array::TwoStageDecimator>` provided by the
library, the :c:func:`mic_array_init_custom_filter` function is used to
initialize a mic array instance with a custom 2-stage decimation filter.

.. note::

  The custom filter provided to :c:func:`mic_array_init_custom_filter` must
  be compatible with the :cpp:class:`TwoStageDecimator
  <mic_array::TwoStageDecimator>` requirements. Specifically, it must be a
  2-stage filter. The tap count and decimation factor for the first-stage
  decimator are fixed at ``256`` and ``32``, respectively, and the filter must
  be compatible with the :ref:`stage_1_filter_impl`.

  The second-stage decimation filter tap count and decimation ratio are flexible,
  provided it is a standard FIR filter compatible with :ref:`stage_2_filter_impl`.
  Using custom filters that are incompatible with the implementation in
  :cpp:class:`TwoStageDecimator <mic_array::TwoStageDecimator>` is outside the
  scope of this documentation.

The :c:type:`mic_array_conf_t` structure is populated with the decimator and
PDM RX configurations before calling
:c:func:`mic_array_init_custom_filter`. In particular, the application must:

- Allocate all filter coefficient buffers, filter state buffers, and PDM RX
  buffers referenced by the decimator and PDM RX configurations, and ensure
  they persist for the lifetime of the mic array instance (until
  :c:func:`mic_array_start` returns).

- Populate the decimator pipeline configuration
  (:c:type:`mic_array_decimator_conf_t`) and the PDM RX configuration
  (:c:type:`pdm_rx_config_t`) structures.

.. note::

  When designing custom filters as described in
  :ref:`designing_custom_filters`, the filter coefficient arrays and associated
  configuration parameters can be written to a header file by running
  ``combined.py``. This file is included in the application, and the decimation
  filter coefficients and other parameters in
  :c:type:`mic_array_filter_conf_t` are populated from it.

  The application must still allocate persistent runtime buffers for the
  filter delay line (:c:type:`mic_array_filter_conf_t`) and for the
  PDM RX input and output buffers
  (:c:type:`pdm_rx_conf_t`).

Below is a snippet from the :ref:`mic_array_example_custom_filter` source code
showing how the :c:type:`mic_array_conf_t` structure is populated:

.. code-block:: c

  #include "good_2_stage_filter.h" // Autogenerated by running 'python combined.py filter_design/good_2_stage_filter_int.pkl -fp good_2_stage_filter'

  void init_mic_conf(mic_array_conf_t &mic_array_conf, mic_array_filter_conf_t (&filter_conf)[2], unsigned *channel_map)
  {
    static int32_t stg1_filter_state[APP_MIC_COUNT][8];
    static int32_t stg2_filter_state[APP_MIC_COUNT][GOOD_2_STAGE_FILTER_STG2_TAP_COUNT];
    memset(&mic_array_conf, 0, sizeof(mic_array_conf_t));

    //decimator
    mic_array_conf.decimator_conf.filter_conf = &filter_conf[0];
    mic_array_conf.decimator_conf.num_filter_stages = 2;
    // filter stage 1
    filter_conf[0].coef = (int32_t*)good_2_stage_filter_stg1_coef;
    filter_conf[0].num_taps = GOOD_2_STAGE_FILTER_STG1_TAP_COUNT;
    filter_conf[0].decimation_factor = GOOD_2_STAGE_FILTER_STG1_DECIMATION_FACTOR;
    filter_conf[0].state = (int32_t*)stg1_filter_state;
    filter_conf[0].shr = GOOD_2_STAGE_FILTER_STG1_SHR;
    filter_conf[0].state_words_per_channel = filter_conf[0].num_taps/32; // works on 1-bit samples
    // filter stage 2
    filter_conf[1].coef = (int32_t*)good_2_stage_filter_stg2_coef;
    filter_conf[1].num_taps = GOOD_2_STAGE_FILTER_STG2_TAP_COUNT;
    filter_conf[1].decimation_factor = GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR;
    filter_conf[1].state = (int32_t*)stg2_filter_state;
    filter_conf[1].shr = GOOD_2_STAGE_FILTER_STG2_SHR;
    filter_conf[1].state_words_per_channel = GOOD_2_STAGE_FILTER_STG2_TAP_COUNT;

    // pdm rx
    static uint32_t pdmrx_out_block[APP_MIC_COUNT][GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR];
    static uint32_t __attribute__((aligned(8))) pdmrx_out_block_double_buf[2][APP_MIC_COUNT * GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR];
    mic_array_conf.pdmrx_conf.pdm_out_words_per_channel = GOOD_2_STAGE_FILTER_STG2_DECIMATION_FACTOR;
    mic_array_conf.pdmrx_conf.pdm_out_block = (uint32_t*)pdmrx_out_block;
    mic_array_conf.pdmrx_conf.pdm_in_double_buf = (uint32_t*)pdmrx_out_block_double_buf;
    mic_array_conf.pdmrx_conf.channel_map = channel_map;
  }

Once :c:type:`mic_array_conf_t` is populated, mic array can be initialised by calling :c:func:`mic_array_init_custom_filter`
and started by calling :c:func:`mic_array_start`:

.. code-block:: c

  unsigned channel_map[2] = {0,1};
  mic_array_conf_t mic_array_conf;
  mic_array_filter_conf_t filter_conf[2];
  init_mic_conf(mic_array_conf, filter_conf, channel_map);
  mic_array_init_custom_filter(&pdm_res, &mic_array_conf);

  par {
    mic_array_start((chanend_t) c_audio_frames);

    <... other tasks ...>
  }

.. note::

    Apart from calling :c:func:`mic_array_init_custom_filter` instead of
    :c:func:`mic_array_init`, all other aspects of using the custom filter API, such
    as including the mic array in an application, declaring resources, and overriding
    build-time default configuration, are exactly the same as in the default usage
    model described in :ref:`using_mic_array`.
