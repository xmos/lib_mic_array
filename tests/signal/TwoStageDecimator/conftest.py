# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
 
import sys, os, pytest
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..','..',"script"))

def pytest_addoption(parser):
    parser.addoption("--build-dir", action="store", default='.')
    parser.addoption("--blocks", type=int, default=160)
    parser.addoption("--dump-obj", action="store_true")
    parser.addoption("--print-output", action="store_true")

# Relative to build directory
APP_BUILD_DIR = os.path.join('tests','signal','TwoStageDecimator')

# Each app is prefixed with this
XE_NAME_ROOT = 'tests-signal-decimator'

# Parameters come from CMakeLists.txt.  If that changes, this may also need
# to change.
xe_params = [
  (1, 1, 1),
  (1, 1, 2),
  (2, 1, 1),
  (2, 1, 16),
  (4, 6, 16),
  (8, 6, 48),
  (1, 6, 48),
  (2, 6, 65),
  (4, 3, 65),
  (8, 3, 24),
]

test_params = [
  pytest.param((x,y,z), id=f"{x}ch_{y}df_{z}tc") for x,y,z in xe_params
]

# Get the file path given params and build_dir
def xe_file_path(params, build_dir):
  xe_name = f"{XE_NAME_ROOT}_{params[0]}_{params[1]}_{params[2]}.xe"
  xe_path = os.path.abspath(
    os.path.join(build_dir, APP_BUILD_DIR, xe_name)
  )
  return xe_path