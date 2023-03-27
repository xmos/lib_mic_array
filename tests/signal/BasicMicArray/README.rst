
tests-signal-BasicMicArray
==========================

Tests in this directory ensure that the signal processing performed by the
``BasicMicArray`` prefab class template behaves as expected. This exercises the
whole mic array unit from the PDM rx input to the output of the framing
component.

Each of these scripts are run using ``pytest``, which will launch the
application in the debugger.

* ``test_mic_array.py`` - Tests ``BasicMicArray`` in various configurations

Build Targets
-------------

Several CMake targets are generated, and all should be built prior to running
the test script in Pytest.

To build all ``tests-signal-BasicMicArray`` targets, (with your CMake project
properly configured) navigate to your CMake build directory and use the
following command:

::

  make tests-signal-BasicMicArray


Running Tests
-------------

Test cases should be run from the base of your CMake build directory. From
there, with Python3 and the XMOS XTC tools in your path, simply call pytest with
the path to the test script as the only necessary argument. For example, to run
``test_mic_array.py``:

::

  pytest ..\tests\signal\BasicMicArray\test_mic_array.py 

