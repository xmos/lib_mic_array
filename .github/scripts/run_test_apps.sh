# This script expects to be run from the root of the mic_array repo

pwd
BINARY_PATH=build.xcore/
pushd ${BINARY_PATH}

# Unit tests
xrun --xscope tests/unit/tests-unit.xe

# Signal/Decimator tests
pytest ../tests/signal/TwoStageDecimator/ -vv

# Filter design tests
# TODO fix - https://github.com/xmos/lib_mic_array/issues/201
# pytest ../tests/signal/FilterDesign/ -vv

popd
