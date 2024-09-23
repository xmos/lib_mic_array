# Copyright 2022-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
 
import sys, os, pytest
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..','..',"script"))

def pytest_addoption(parser):
    parser.addoption("--build-dir", action="store", default='.')
    parser.addoption("--blocks", type=int, default=160)
    parser.addoption("--dump-obj", action="store_true")
    parser.addoption("--print-output", action="store_true")
