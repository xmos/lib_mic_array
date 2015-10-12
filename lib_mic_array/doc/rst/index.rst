.. include:: ../../../README.rst

Microphone array library
------------------------









API
---

Supporting types
................

.. doxygenenum:: i2s_mode_t

.. doxygenstruct:: i2s_config_t

.. doxygenstruct:: tdm_config_t

.. doxygenenum:: i2s_restart_t


|newpage|

Creating an I2S instance
........................

.. doxygenfunction:: i2s_master

|newpage|

.. doxygenfunction:: i2s_slave

|newpage|

Creating an TDM instance
........................

.. doxygenfunction:: tdm_master

|newpage|

.. doxygenfunction:: i2s_tdm_master

|newpage|

The I2S callback interface
..........................

.. doxygeninterface:: i2s_callback_if

|appendix|

Known Issues
------------

No known issues.

.. include:: ../../../CHANGELOG.rst
