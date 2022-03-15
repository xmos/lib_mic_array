
## tests-build-vanilla

This directory contains build tests for the vanilla API.

These tests are intended only to ensure:

* `MicArray` class templates derived from the prefab API can build correctly (with various configurations) in an actual application
* Mic Array unit can be started and actually deliver frames of audio.

> Note: The contents of delivered audio frames are ignored.

### Build Targets

Because the vanilla API uses preprocessor definitions to specify the build parameters, a separate target with different preprocessor defintions must be generated for each test configuration.

A custom target, called `tests-build-vanilla`, is defined which builds each generated test target. The following command, run from the CMake build directory, will build all targets.

```
make -j tests-build-vanilla
```

### Configurations Tested

This test currently builds an application using the vanilla API which varies each of the following parameters and values:

* Mic Count: 1, 2
* Frame Size: 1, 16, 256
* PDM Freq:  3.072 MHz, 6.144 MHz
* DC Offset Elimination:  disabled, enabled