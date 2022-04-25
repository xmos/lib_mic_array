
tests-build
===========

Tests in this directory are meant to ensure that the mic array code will
correctly build with various configurations. This is necessary because this
library makes use of C++ class templates, which are not instantiated until used
in an application.

* `vanilla`_ - Build tests using the vanilla API
* `prefab`_ - Build tests using the prefab API


Build Targets
-------------

For these tests, building the targets is most of the test.

To build all ``tests-build`` test cases, (with your CMake project properly
configured) navigate to your CMake build directory and use the following
command:

::

    make tests-build

To build only the ``vanilla`` or ``prefab`` targets, use ``tests-build-vanilla`` and ``tests-build-prefab`` respectively.


Running Test Apps
-----------------

The generated binaries can be run with ``xrun`` to verify that no run-time exceptions happen during initialization or steady-state operation.

.. _vanilla: vanilla/
.. _prefab: prefab/