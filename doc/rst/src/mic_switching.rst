.. _mic_switching:

********************
Single-mic override
********************

The number of microphone input and output channels is ordinarily fixed at compile time
via :c:macro:`MIC_ARRAY_CONFIG_MIC_COUNT` and :c:macro:`MIC_ARRAY_CONFIG_MIC_IN_COUNT`.

In some cases, however, an application may need to dynamically switch between operating
with a single microphone and its normal multi-microphone configuration (as defined by
its compile time configuration). This can be useful, for example, to reduce processing load during idle periods.

The :c:func:`mic_array_enable_1mic_override` function facilitates this. When called
before :c:func:`mic_array_init` (or :c:func:`mic_array_init_custom_filter`), it causes
the mic array to behave as if both :c:macro:`MIC_ARRAY_CONFIG_MIC_COUNT` and
:c:macro:`MIC_ARRAY_CONFIG_MIC_IN_COUNT` were set to ``1``, regardless of their
configured values. In this mode, only the first microphone channel is processed and emitted.

.. note::

  :c:func:`mic_array_enable_1mic_override` is intended for use with a 1-bit PDM
  data port configuration. It is not applicable for configurations where the PDM
  data port width is greater than 1.

Switching from multi-mic to single-mic mode
===========================================

To switch to single-mic mode:

* Call :c:func:`ma_shutdown` to terminate the running mic array.
* Call :c:func:`mic_array_enable_1mic_override` to activate the override.
* Call :c:func:`mic_array_init` (or :c:func:`mic_array_init_custom_filter`) and :c:func:`mic_array_start` to restart in single-mic mode.

.. note::

  The output frame size received by :c:func:`ma_frame_rx` changes when switching
  modes, because the number of channels changes. The receiving thread must be updated
  accordingly.

Switching back to multi-mic mode
=================================

The override is automatically cleared by :c:func:`ma_shutdown`. To return to
multi-mic operation, simply shut down and restart **without** calling
:c:func:`mic_array_enable_1mic_override`.

An example of the :c:func:`mic_array_enable_1mic_override` API can be found in :ref:`mic_array_app_1mic_override`
