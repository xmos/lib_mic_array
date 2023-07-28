# This script expects to be run from the root of the mic_array repo
pwd
BINARY_PATH=build.xcore/tests/
xrun --xscope ${BINARY_PATH}unit/tests-unit.xe
