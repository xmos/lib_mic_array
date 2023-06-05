


Scripts
=======

stage1.py and stage2.py
-----------------------

These scripts can be used to generate C code representing the required first and
second stage filters used by the mic array.

* ``stage1.py`` outputs an array for the first stage filter
* ``stage2.py`` outputs an array for the second stage filter

Each script takes a Python ``.pkl`` file as an input (via the command line), and
outputs a simple C-style array initializer in the terminal. That output can be
used to overwrite the filter coefficients in an application.

Example
'''''''

The following is an example of running ``stage1.py``.

.. code::

  lib_mic_array\script>python stage1.py filter_design\good_2_stage_filter_int.pkl
  Stage 1 Decimation Factor: 32
  Stage 1 Tap Count: 125
  Stage 2 Decimation Factor: 6
  Stage 2 Tap Count: 256

  Filter word count: 128

  {
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xEEEEEEEE, 0xEEEEEEEE, 0xEEEEEEEE, 0xEEEEEEEE,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFAFAFAFA, 0xFAFAFAFA, 0xEBEBEBEB, 0xEBEBEBEB,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xF5A0F5A0, 0xE4B1E4B1, 0xF1A4F1A4, 0xE0B5E0B5,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFB51AE04, 0xEF54BA01, 0xF00BA55E, 0xE40EB15B,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFD1353BD, 0xB31809B3, 0xF9B20319, 0xB7B95917,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFE4D120F, 0x584AEB52, 0xA95AEA43, 0x5E09164F,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFF94E621, 0x17931C80, 0x0027193D, 0x108CE53F,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFE6AE34, 0xE549505E, 0xEF415254, 0xE58EACFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFF8CB6C, 0x066D9FCB, 0x1A7F36CC, 0x06DA63FF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFF0C49, 0x52DB4A93, 0xF92A5B69, 0x52461FFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFF071, 0x9B6D931C, 0x071936DB, 0x31C1FFFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFF81, 0xE38E1C1F, 0xFF070E38, 0xF03FFFFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFE, 0x03F01FE0, 0x00FF01F8, 0x0FFFFFFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFC001FFF, 0xFFFF0007, 0xFFFFFFFF,
    0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFE000, 0x0000FFFF, 0xFFFFFFFF,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
  }

Here, the input ``.pkl`` file ``good_2_stage_filter_int.pkl`` was generated
using ``filter_design/design_filter.py``. The script outputs some basic
information about the filter followed by a C array initializer of 128 words.

The output array can be used to initialize an array of type ``uint32_t``. The
values in the array may appear to have little relation to those directly in the
``.pkl`` file because the implementation of the first stage filter requires the
coefficients to be reordered in a bit-wise manner for run-time optimization.

The following is an example of ``stage2.py`` being run with the same input file.

.. code::

  lib_mic_array\script>python stage2.py filter_design\good_2_stage_filter_int.pkl
  Stage 1 Decimation Factor: 32
  Stage 1 Tap Count: 125
  Stage 2 Decimation Factor: 6
  Stage 2 Tap Count: 256

  Right-shift: 4

  {
  0x12cbd, 0x1bc68, 0x1e848, 0x16e3b, 0x34fc, -0x19c13, -0x396a4, -0x517d3, -0x572c4, -0x42a99, -0x12b2d, 0x3136a, 0x78fc9, 0xaf0c5, 0xbdfb3, 0x976fb, 0x3a55b, -0x49c82, -0xd5ee1, -0x141f1d, -0x166e07, -0x12b197, -0x8cb56, 0x594d5, 0x151a2b, 0x217aba, 0x268fd9, 0x219572, 0x123738, -0x4ec96, -0x1e8a6b, -0x33c24b, -0x3ddb52, -0x383953, -0x220324, 0x10d0c, 0x290b3c, 0x4b7d38, 0x5df58f, 0x590923, 0x3ad314, 0x83f9d, -0x336a4b, -0x68da62, -0x887959, -0x86bb28, -0x5fdb9e, -0x19e511, 0x3bc670, 0x8b8db4, 0xbedc73, 0xc4446c, 0x94e8ba, 0x379c2f, -0x3f6e52, -0xb2ae73, -0x10257a9, -0x114d20e, -0xde6ae6, -0x66087d, 0x3abb9a, 0xdc9726, 0x153d6f5, 0x17bd0e7, 0x141966a, 0xaae708, -0x28e308, -0x106c5f0, -0x1b3f8e6, -0x1fd12db, -0x1c4a9b6, -0x10d64a6, 0x3a8af, 0x12db80b, 0x2232795, 0x29d2c56, 0x26f81a8, 0x196c603, 0x3d29f5, -0x14cb2a5, -0x2a1db99, -0x3623ba6, -0x34cc828, -0x253b843, -0xa4d6a3, 0x15d59b2, 0x33128a8, 0x45581b2, 0x46c6158, 0x357091a, 0x143e5e3, -0x156ca08, -0x3d3d9c1, -0x586bd77, -0x5e8a05f, -0x4bf99e5, -0x235288f, 0x12b764c, 0x490cfd8, 0x713c998, 0x7f2705a, 0x6c6a6e1, 0x3aa1c29, -0xc38997, -0x578b750, -0x93c3c2b, -0xaf1da5a, -0x9e75bfb, -0x60eaa5b, -0x14591a, 0x6b69c4c, 0xc9ef41c, 0xff16c12, 0xf689a74, 0xa8d3041, 0x1f08228, -0x8cffe95, -0x13445d3b, -0x1a994e72, -0x1c28c7ca, -0x160ef96b, -0x7a3c5f0, 0xe431389, 0x295878fd, 0x4629d110, 0x60af1114, 0x74fe4fe9, 0x7fffffff, 0x7fffffff, 0x74fe4fe9, 0x60af1114, 0x4629d110, 0x295878fd, 0xe431389, -0x7a3c5f0, -0x160ef96b, -0x1c28c7ca, -0x1a994e72, -0x13445d3b, -0x8cffe95, 0x1f08228, 0xa8d3041, 0xf689a74, 0xff16c12, 0xc9ef41c, 0x6b69c4c, -0x14591a, -0x60eaa5b, -0x9e75bfb, -0xaf1da5a, -0x93c3c2b, -0x578b750, -0xc38997, 0x3aa1c29, 0x6c6a6e1, 0x7f2705a, 0x713c998, 0x490cfd8, 0x12b764c, -0x235288f, -0x4bf99e5, -0x5e8a05f, -0x586bd77, -0x3d3d9c1, -0x156ca08, 0x143e5e3, 0x357091a, 0x46c6158, 0x45581b2, 0x33128a8, 0x15d59b2, -0xa4d6a3, -0x253b843, -0x34cc828, -0x3623ba6, -0x2a1db99, -0x14cb2a5, 0x3d29f5, 0x196c603, 0x26f81a8, 0x29d2c56, 0x2232795, 0x12db80b, 0x3a8af, -0x10d64a6, -0x1c4a9b6, -0x1fd12db, -0x1b3f8e6, -0x106c5f0, -0x28e308, 0xaae708, 0x141966a, 0x17bd0e7, 0x153d6f5, 0xdc9726, 0x3abb9a, -0x66087d, -0xde6ae6, -0x114d20e, -0x10257a9, -0xb2ae73, -0x3f6e52, 0x379c2f, 0x94e8ba, 0xc4446c, 0xbedc73, 0x8b8db4, 0x3bc670, -0x19e511, -0x5fdb9e, -0x86bb28, -0x887959, -0x68da62, -0x336a4b, 0x83f9d, 0x3ad314, 0x590923, 0x5df58f, 0x4b7d38, 0x290b3c, 0x10d0c, -0x220324, -0x383953, -0x3ddb52, -0x33c24b, -0x1e8a6b, -0x4ec96, 0x123738, 0x219572, 0x268fd9, 0x217aba, 0x151a2b, 0x594d5, -0x8cb56, -0x12b197, -0x166e07, -0x141f1d, -0xd5ee1, -0x49c82, 0x3a55b, 0x976fb, 0xbdfb3, 0xaf0c5, 0x78fc9, 0x3136a, -0x12b2d, -0x42a99, -0x572c4, -0x517d3, -0x396a4, -0x19c13, 0x34fc, 0x16e3b, 0x1e848, 0x1bc68, 0x12cbd
  }

Similar output is produced. In addition to the filter coefficient array,
``stage2.py`` outputs a right-shift (here ``4``) which is needed by the second
stage filter.

The simplest way to use these coefficients in an application is to replace the
values in ``../lib_mic_array/src/etc/stage1_fir_coef.c`` and
``../lib_mic_array/src/etc/stage2_fir_coef.c``.

Input pkl File
''''''''''''''

``stage1.py`` and ``stage2.py`` load the contents of the supplied ``.pkl`` file
using ``pickle.load()``` from the ``pickle`` Python module. They expect the
result of ``load()`` to have type compatible with
``Tuple[Tuple[numpy.ndarray,int],Tuple[numpy.ndarray,int]]``. The following
pseudo-code should help clarify this:

.. code:: python

  stage1, stage2 = pkl.load(filter_coef_pkl_file)
  stage1_coef_array, stage1_decimation_factor = stage1
  stage2_coef_array, stage2_decimation_factor = stage2

  assert stage1_coef_array.dtype == np.int16
  assert stage2_coef_array.dtype == np.int32
  assert stage1_decimation_factor == 32

Further constraints, as illustrated above, are that the stage1 filter
coefficients should be ``np.int16`` (signed 16-bit integers) and stage2 filter
coeffiients should be ``np.int32`` (signed 32-bit integers). Further, the first
stage filter currently only supports a decimation factor of ``32``.

Using Custom Coefficients in an Application
'''''''''''''''''''''''''''''''''''''''''''

The C files ../lib_mic_array/src/etc/stage1_fir_coef.c and
../lib_mic_array/src/etc/stage2_fir_coef.c provide an example of how the outputs
of ``stage1.py`` and ``stage2.py`` may be used. 

.. note:: If the stage 2 decimation factor or tap count changes `../lib_mic_array/api/etc/filters_default.h` must also be updated to reflect that change.

The filter coefficients used by the decimator as specified when initializing the
decimator (e.g. ``mic_array::TwoStageDecimator``). To use custom coefficients
when directly working with the mic array's C++ objects, simply provide a pointer
to your custom coefficients to the decimator's ``Init()`` method.

Alternatively, ``lib_mic_array``'s Vanilla API and the
``mic_array::prefab::BasicMicArray`` class template both automatically use the
filter coefficients given by the symbols ``stage1_coef``, ``stage2_coef`` and
``stage2_shr`` when initializing the decimator.

In that case, there are two options to use custom filter. The first and easiest
is to simply overwrite the coefficients given in
``../lib_mic_array/src/etc/stage1_fir_coef.c`` and
``../lib_mic_array/src/etc/stage2_fir_coef.c``. If that is not an option, you
may also add your own source files containing your coefficients to your project
(using the same symbol names) and exclude ``stage1_fir_coef.c`` and
``stage2_fircoef.c`` from the project's source files.
