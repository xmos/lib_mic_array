
tests
=====

This directory contains the tests for ``lib_mic_array``.

  - ``building/`` - Tests which ensure the various C++ class templates build correctly.
  - ``etc/`` - (No tests) Contains assorted bits neededed by some test applications.
  - ``signal/`` - ``pytest``-based functional tests which verify mic array signal processing
  - ``unit/`` - Unit tests for individual components.

Test CMake Targets
------------------

Many individual CMake targets are generated for the test applications. For some
(Unity-based tests), a single binary contains many test cases. For others (pytest-based tests) several binaries are used for single tests.

The CMake target ``tests`` includes all test binaries. Likewise, the CMake
targets ``tests.building``, ``tests.signal`` and ``tests.unit`` include their
respective subsets of test cases.

Building tests
--------------

With your CMake project properly configured, to build all test binaries, 
navigate to your CMake build directory and use the following command:

::

  make tests
