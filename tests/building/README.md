
## tests-build

Tests in this directory are meant to ensure that the mic array code will correctly build with various configurations.

* `vanilla/` - Build tests using the vanilla API
* `prefab/` - Build tests using the prefab API

All build tests can be build by running

```
make -j tests-build
```

from the CMake build directory.