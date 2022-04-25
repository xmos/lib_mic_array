
tests
=====

This directory contains the tests for ``lib_mic_array``.

* `building`_ - Tests which ensure the various C++ class templates build correctly.
* ``etc/`` - (No tests) Contains assorted bits neededed by some test applications.
* `signal`_ - ``pytest``-based functional tests which verify mic array signal
  processing
* `unit`_ - Unit tests for individual components.

Test CMake Targets
------------------

Many individual CMake targets are generated for the test applications. For some
(Unity-based tests), a single binary contains many test cases. For others
(pytest-based tests) several binaries are used for single tests.

The CMake target ``tests`` includes all test binaries. Likewise, the CMake
targets ``tests-build``, ``tests-signal`` and ``tests-unit`` include their
respective subsets of test cases.

Building tests
--------------

With your CMake project properly configured, to build all test binaries, 
navigate to your CMake build directory and use the following command:

::

  make tests


Running tests
-------------

Each group of tests is run differently.

For the tests associated with the ``tests-build`` CMake target, building the
targets is itself the test. It ensures that there are no syntax or other errors
in the C++ class templates defined in the library (because no actual 
implementation of the template is generated until an application uses it).

The test cases associated with the ``tests-unit`` CMake target use the Unity 
unit test framework.  The compiled binaries are stand-alone test applications 
that can be run using ``xrun``.

The test cases associated with the ``tests-signal`` CMake target use the
``pytest`` framework. See `signal`_ for more information.

.. _building: building/
.. _signal: signal/
.. _unit: unit/