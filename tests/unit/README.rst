
tests-unit
==========

This directory contains unit tests for various elements of this library.

These tests use the Unity unit testing framework, which should have been
automatically fetched when configuring the CMake project.


Build Target
------------

To build the unit tests, navigate to your CMake build directory and use the
following command:

::

  make tests-unit


Running Tests
-------------

Test cases are executed by running the generated binary with ``xrun``. E.g., from the CMake build directory:

::

  xrun --xscope tests\unit\tests-unit.xe

