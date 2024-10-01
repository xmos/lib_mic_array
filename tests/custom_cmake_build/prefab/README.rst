
tests-build-prefab
==================

This directory contains build tests for the prefab API.

These tests are intended only to ensure:

* ``MicArray`` class templates derived from the prefab API can build correctly
  (with various configurations) in an actual application
* Mic Array unit can be started and actually deliver frames of audio.

> Note: The contents of delivered audio frames are ignored.

Build Targets
-------------

A single target, called `tests-build-prefab`, is defined for this test.

To build, (with your CMake project properly configured) navigate to your CMake
build directory and use the following command:

::

    make tests-build-prefab


Configurations Tested
---------------------

This test currently builds an application which instantiates the
``mic_array::prefab::BasicMicArray<>`` class template using combinations of each
of the following parameters and values:

* Mic Count: 1, 2
* Frame Size: 1, 16, 256
* DC Offset Elimination:  disabled, enabled