# Copyright 2022-2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

######
# Test: test_pdmrx_isr
#
# This test checks that the credit based scheme implemented in PDM RX ISR works
#
# Notes:
#  - This test assumes that the CMake targets for this app are all already
#    built.
#  - This test directly launches xgdb, and so the XTC tools must be on your
#    path.
#  - An appropriate xCore device must be connected to the host using xTag
#  - This test should be executed with pytest. To run it, navigate to the root
#    of your CMake build directory, and run:
#       > pytest path/to/this/dir/test_pdmrx_isr.py
######

from pathlib import Path
import subprocess

def test_pdmrx_isr(request):
  cwd = Path(request.fspath).parent
  xe_path = f'{cwd}/bin/tests_signal_pdmrx_isr.xe'
  assert Path(xe_path).exists(), f"Cannot find {xe_path}"

  cmd = ["xrun", "--id", "0", "--xscope", xe_path]

  result = subprocess.run(
      cmd,
      capture_output=True,
      text=True,
      check=True,
      timeout=30
  )
  print("STDOUT:\n", result.stdout)
  if result.stderr:
    print("STDERR:\n", result.stderr)

