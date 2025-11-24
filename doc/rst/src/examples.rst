
********
Examples
********

Example applications are included with ``lib_mic_array`` to illustrate both the
default usage model and advanced/custom integration approaches.

These examples are located in the ``examples`` directory of the library.
All examples run on the
`XK-VOICE-L71 <https://www.xmos.com/xk-voice-l71>`_ hardware platform.

Examples overview:

* ``app_mic_array`` — demonstrates the :ref:`default <mic_array_default_model>` way of using the mic array in an application (recommended starting point).
* ``app_shutdown`` — demonstrates :ref:`shutting down and restarting <shutdown>` the mic array.
* ``app_par_decimator`` — demonstrates an :ref:`advanced <mic_array_adv_use_methods>` integration approach.
  Replaces the standard decimator component with a custom two-threaded implementation.
* ``app_prefab`` — demonstrates using the Prefab API (DEPRECATED).

Running the examples
====================

This section describes how to build and run the example applications provided
with the ``lib_mic_array`` library.
The application used here is ``app_mic_array`` which demonstrates use of the
default mic array API.
For other examples, the process is similar, except for the application/folder name.

Required hardware
-----------------

- 1x ``XK-VOICE-L71`` board
- 2x Micro USB cable (For USB power and XTAG)
- 3.5mm audio cable to connect to the line out connector on the ```XK-VOICE-L71`` board

Setup procedure
---------------

#. Connect the XTAG to the ``XK-VOICE-L71``

#. Connect one Micro USB cable between the host computer and the ``XK-VOICE-L71`` **USB** port.

#. Connect the other Micro USB cable between the host computer and the XTAG.

:ref:`l71_hw_setup` shows the ``XK-VOICE-L71`` board with all the cables connected.

.. _l71_hw_setup:

.. figure:: mic_array_l71.*
   :width: 80%

   XK-VOICE-L71 setup


Building
--------

The following instructions assumes that the `XMOS XTC tools <https://www.xmos.com/software-tools/>`_ has
been downloaded and installed (see `README` for required version).

Installation instructions can be found `here <https://xmos.com/xtc-install-guide>`_. Particular
attention should be paid to the section `Installation of required third-party tools
<https://www.xmos.com/documentation/XM-014363-PC-10/html/installation/install-configure/install-tools/install_prerequisites.html>`_.

The application uses the `XMOS` build and dependency system,
`xcommon-cmake <https://www.xmos.com/file/xcommon-cmake-documentation/?version=latest>`_. `xcommon-cmake` is bundled with the `XMOS` XTC tools.

To configure the build, run the following from an XTC command prompt:

.. code-block:: console

  cd examples
  cd app_mic_array
  cmake -G "Unix Makefiles" -B build

Any missing dependencies will be downloaded by the build system at this configure step.

Finally, the application binaries can be built using ``xmake``:

.. code-block:: console

  xmake -j -C build

The example build four configurations - ``1mic_isr``, ``1mic_thread``, ``2mic_isr`` and ``2mic_thread``,
which indicate the number of microphones used and whether the PDM RX service runs in an ISR or a hardware thread.
The executable binaries (.xe files) for each configuration are placed in ``bin/<config>`` directory
(e.g. ``bin/2mic_isr/app_mic_array_2mic_isr.xe``).

Running the application
-----------------------

To run the application from the ``/examples/app_mic_array`` directory, execute:

.. code-block:: console

  xrun --xscope bin/2mic_isr/app_mic_array_2mic_isr.xe

The command above runs the ``2mic_isr`` configuration.
To run a different configuration, replace ``2mic_isr`` in the path with the desired build variant.

When running, the application captures the microphones audio and routes it to the DAC
on the ``XK-VOICE-L71`` after linearly scaling the PCM samples received from ``lib_mic_array``
by a factor of 64.
Connect headphones to the 3.5mm LINE OUT jack on the board to listen to the captured microphone signal.


Other examples
--------------
.. _mic_array_par_decimator:

``app_par_decimator``
^^^^^^^^^^^^^^^^^^^^^

The ``app_par_decimator`` example behaves like ``app_mic_array``, but internally uses a :ref:`custom
mic array <mic_array_adv_use_methods>` decimator implementation. The custom decimator runs in two threads, with each thread
processing one channel of microphone output. This example serves as a reference for using
``lib_mic_array`` in applications with many microphone channels, where decimation must be
split across multiple hardware threads (e.g., two decimator threads, each handling four channels).

.. _mic_array_app_shutdown:

``app_shutdown``
^^^^^^^^^^^^^^^^

The ``app_shutdown`` example demonstrates shutting down and restarting the mic array each time
``Button A`` on the ``XK-VOICE-L71`` is pressed. Each press shuts down the mic array component
and restarts it at a different output sampling frequency, cycling between 16 kHz and 48 kHz.

The terminal stdout displays the current sampling rate on each button press:

.. code-block:: console

    Starting at sample rate 16000
    Starting at sample rate 48000
    Starting at sample rate 16000
    Starting at sample rate 48000
    Starting at sample rate 16000
    Starting at sample rate 48000
    Starting at sample rate 16000
