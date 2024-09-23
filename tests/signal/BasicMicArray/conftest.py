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


class DevCommand(enum.Enum):
  RESUME = 0
  TERMINATE = 1
  PRINT_FILTERS = 2