
Using the mic_array - default model or with custom filters
----------------------------------------------------------

.. _mic_array_default_model_defines:

Configuration defines (mic_array_conf_default.h)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

An application using the mic array needs to have defines set for compile-time configuration of the mic array instance.
Defaults for these defines are defined in the header file ``mic_array_conf_default.h``.
These defines should be overridden in an optional header file  ``mic_array_conf.h`` file or in the application's ``CMakeLists.txt``.

This section fully documents all of the settable defines and their default values.

.. doxygendefine:: MIC_ARRAY_CONFIG_MIC_COUNT
.. doxygendefine:: MIC_ARRAY_CONFIG_MIC_IN_COUNT
.. doxygendefine:: MIC_ARRAY_CONFIG_USE_PDM_ISR
.. doxygendefine:: MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME
.. doxygendefine:: MIC_ARRAY_CONFIG_USE_DC_ELIMINATION

Function definitions (mic_array_task.h)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The header file ``mic_array_task.h`` contains the function API declarations that the application
needs to call to initialise and start a mic array instance when using the default model
(:c:func:`mic_array_init` and :c:func:`mic_array_start`) or when using custom filter
(:c:func:`mic_array_init_custom_filter` and :c:func:`mic_array_start`).

.. doxygenfunction:: mic_array_init

.. doxygenfunction:: mic_array_start

.. doxygenfunction:: mic_array_init_custom_filter
