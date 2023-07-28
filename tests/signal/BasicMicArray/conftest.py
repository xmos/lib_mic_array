# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
 
import sys, os, pytest, enum
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..','..',"script"))


FLAGS = [
  "print-output",
  "print-xgdb",
  "debug-print-filters"
]

def pytest_addoption(parser):
    parser.addoption("--build-dir", action="store", default='.')
    parser.addoption("--frames", type=int, default=40)

    addflag = lambda x: parser.addoption(f"--{x}", action="store_true")

    [addflag(x) for x in FLAGS]

# Relative to build directory
APP_BUILD_DIR = os.path.join('tests','signal','BasicMicArray')

# Each app is prefixed with this
XE_NAME_ROOT = 'tests-signal-basicmicarray'

# Parameters come from CMakeLists.txt.  If that changes, this may also need
# to change.

# (MICS, FRAME_SIZE, USE_ISR)
xe_params = [
  (1, 1,   0),
  (1, 16,  0),
  (2, 1,   0),
  (2, 16,  0),
  (4, 1,   0),
  (4, 16,  0),
  (8, 1,   0),
  (8, 16,  0),
  (8, 64,  0),
  (1, 1,   1),
  (1, 16,  1),
  (2, 1,   1),
  (2, 16,  1),
  (4, 1,   1),
  (4, 16,  1),
  (8, 1,   1),
  (8, 16,  1),
  (8, 64,  1),
]

test_params = [
  pytest.param((x,y,z), id=f"{x}ch_{y}smp_{z}") for x,y,z in xe_params
]

# Get the file path given params and build_dir
def xe_file_path(params, build_dir):
  xe_name = f"{XE_NAME_ROOT}_{params[0]}ch_{params[1]}smp_{params[2]}.xe"
  xe_path = os.path.abspath(
    os.path.join(build_dir, APP_BUILD_DIR, xe_name)
  )
  return xe_path


class DevCommand(enum.Enum):
  RESUME = 0
  TERMINATE = 1
  PRINT_FILTERS = 2