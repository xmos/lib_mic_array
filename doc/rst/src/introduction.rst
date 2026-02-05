
************
Introduction
************

``lib_mic_array`` provides microphone array processing support on XMOS devices.
It interfaces with one or more PDM (Pulse Density Modulation) microphones, capturing and converting their
output into high-quality PCM audio suitable for downstream voice and audio
processing pipelines.

PDM microphones produce a high-rate, 1-bit digital bitstream. The library
captures these PDM streams on the device and performs the required filtering
and decimation to produce 32-bit PCM audio samples.

For high level description of mic array processing and the library capabilities, refer to :ref:`overview`.
To get started with using the library, see :ref:`using_mic_array` and :ref:`examples`.


.. note::

  From Version 5.0 onwards, the library does not support XS2 or XS1 devices. Please use version 4.5.0 if you need support for these devices: https://github.com/xmos/lib_mic_array/releases/tag/v4.5.0

