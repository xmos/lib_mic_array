:orphan:

tests-build-default
===================

This directory contains build tests for the default API.

These tests are intended only to ensure:

* ``MicArray`` class templates using the default API can build correctly (with
  various configurations) in an actual application
* Mic Array unit can be started and actually deliver frames of audio.

> Note: The contents of delivered audio frames are ignored.

### Build Targets

Because the default API uses preprocessor definitions to specify the build
parameters, a separate target with different preprocessor defintions is
generated for each test configuration.

A custom target, called `tests-build-default`, is defined which builds each
generated test target.

To build, (with your CMake project properly configured) navigate to your CMake
build directory and use the following command:

::

    make tests-build-default


Configurations Tested
---------------------

This test currently builds an application using the default API which varies
each of the following parameters and values:

* Mic Count: 1, 2
* Frame Size: 1, 16, 256
* PDM Freq:  3.072 MHz, 6.144 MHz
* DC Offset Elimination:  disabled, enabled
