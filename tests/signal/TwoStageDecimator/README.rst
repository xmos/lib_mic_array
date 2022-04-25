
tests-signal-TwoStageDecimator
==============================

Tests in this directory ensure that the signal processing performed by the 
``TwoStageDecimator`` class template behaves as expected.

Each of these scripts are run using ``pytest``, which will launch the
application in the debugger.

* ``test_stage1.py`` - Tests the first stage decimator in various configurations
* ``test_stage2.py`` - Tests the second stage decimator in various configurations


Build Targets
-------------

Several CMake targets are generated, and all should be built prior to running
the test script in Pytest.

To build all ``tests-signal-TwoStageDecimator`` targets, (with your CMake
project properly configured) navigate to your CMake build directory and use the
following command:

::

  make tests-signal-TwoStageDecimator


Running Tests
-------------

Test cases should be run from the base of your CMake build directory. From
there, with Python3 and the XMOS XTC tools in your path, simply call pytest with
the path to the test script as the only necessary argument. For example, to run
the TwoStageDecimator stage2 tests:

::

  pytest ..\tests\signal\TwoStageDecimator\test_stage2.py 

