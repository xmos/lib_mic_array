# Copyright 2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

def pytest_addoption(parser):
  parser.addoption(
    "--update",
    action="store_true",
    help=("Overwrite mic_array_memory.json and regenerate mic_array_memory_table.rst. "
         "The comparison check which flags mips/memory being out of range doesn't run in this case.")
  )
