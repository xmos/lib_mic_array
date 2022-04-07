
tests-signal
============

Tests in this directory are meant to ensure that the mic array signal processing
works as expected.

Each of these tests are run using ``pytest``, which will launch the application
in the debugger.

* `BasicMicArray`_ - Build tests using the vanilla API
* `TwoStageDecimator`_ - Build tests using the prefab API

Requirements
------------

To run these tests, you will need Python3 with ``pytest`` and ``numpy``.

> TODO: Create requirements.txt for python virtual environment


Build Targets
-------------

To build all ``tests-signal`` targets, (with your CMake project properly
configured) navigate to your CMake build directory and use the following
command:

::

  make tests-signal


Running Test Apps
-----------------

Test cases should be run from the base of your CMake build directory. From
there, with Python3 and the XMOS XTC tools in your path, simply call pytest with
the path to the test script as the only necessary argument. For example, to run
the TwoStageDecimator stage2 tests:

::

  pytest ..\tests\signal\TwoStageDecimator\test_stage2.py 



.. _BasicMicArray: BasicMicArray/
.. _TwoStageDecimator: TwoStageDecimator/