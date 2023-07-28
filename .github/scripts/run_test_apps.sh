# This script expects to be run from the root of the mic_array repo
# set -e # uncomment when done with dev
pwd
BINARY_PATH=build.xcore/
pushd ${BINARY_PATH}

# Unit tests
xrun --xscope tests/unit/tests-unit.xe

# Signal/Decimator tests
pytest ../tests/signal/TwoStageDecimator/ -vv

# Filter design tests
# TODO fix
# pytest ../tests/signal/FilterDesign/ -vv

popd
