# Copyright 2022-2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

######
# Test: BasicMicArray test
#
# This test is intended to ensure the BasicMicArray prefab appears to produce
# the expected results.
#
# This test does one thing in particular that may seem a bit suspect. Instead of
# reading PDM data from a port, the BasicMicArray is 'tricked' into using a
# streaming chanend as the resource that it reads the data from. Note that doing
# this does not require the BasicMicArray code to be modified in any way (which
# is good).
#
# It also makes the test much easier by evaporating the real-time constraint.
# But that does mean that this test case is in no way verifying that the
# BasicMicArray actually meets the real-time constraint.
#
# Notes:
#  - This test assumes that the CMake targets for this app are all already
#    built.
#  - This test directly launches xgdb, and so the XTC tools must be on your
#    path.
#  - An appropriate xCore device must be connected to the host using xTag
#  - This test should be executed with pytest. To run it, navigate to the root
#    of your CMake build directory, and run:
#       > pytest path/to/this/dir/test_mic_array.py
######

import numpy as np
from mic_array.pdm_signal import PdmSignal
from micarray_device import MicArrayDevice
import pytest
from conftest import DevCommand
import json
from pathlib import Path
from mic_array_shared import MicArraySharedBase

with open(Path(__file__).parent / "test_params.json") as f:
    params = json.load(f)

smoke_test_chans = [8]
smoke_test_frame_sz = [1, 16]
def ma_test_uncollect(config, chans, frame_size, use_isr, fs):
  level = config.getoption("level")
  if level == "smoke":
    if((chans in smoke_test_chans) and (frame_size in smoke_test_frame_sz)):
      return False
    else:
      return True # uncollect everything other than 1_isr-16frame-8n_mics
  return False # for level != smoke, collect everything

class Test_BasicMicArray(MicArraySharedBase):
  @pytest.mark.uncollect_if(func=ma_test_uncollect)
  @pytest.mark.parametrize("chans", params["N_MICS"], ids=[f"{nm}n_mics" for nm in params["N_MICS"]])
  @pytest.mark.parametrize("frame_size", params["FRAME_SIZE"], ids=[f"{fs}frame" for fs in params["FRAME_SIZE"]])
  @pytest.mark.parametrize("use_isr", params["USE_ISR"], ids=[f"{ui}_isr" for ui in params["USE_ISR"]])
  @pytest.mark.parametrize("fs", params["SAMP_FREQ"], ids=[f"{s}" for s in params["SAMP_FREQ"]])
  def test_BasicMicArray(self, request, chans, frame_size, use_isr, fs):
    cwd = Path(request.fspath).parent

    custom_filter_file = None
    if not isinstance(fs, int): # fs must contain the name of the filter .pkl file
      custom_filter_file = fs
      cfg = f"{chans}ch_{frame_size}smp_{use_isr}isr_customfs"
    else:
      cfg = f"{chans}ch_{frame_size}smp_{use_isr}isr_{fs}fs"

    xe_path = f'{cwd}/bin/{cfg}/test_ma_{cfg}.xe'
    assert Path(xe_path).exists(), f"Cannot find {xe_path}"

    frames = request.config.getoption("frames")
    # Generate random filter
    if custom_filter_file:
      filter = self.filter(Path(__file__).parent / f"{custom_filter_file}")
    else:
      filter = self.filter(self.get_default_filter(fs))


    # Number of PDM samples (per channel) required to make the mic array
    # output a single frame
    samp_per_frame = 32 * filter.s2.DecimationFactor * frame_size

    # Total PDM samples (per channel)
    samp_total = samp_per_frame * frames

    # Generate random PDM signal
    sig = PdmSignal.random(chans, samp_total)

    # Compute the expected output
    # Note: This assumes DCOE is disabled (which it should be in this app)
    expected = filter.Filter(sig.signal)

    if self.print_output: print(f"Expected output: {expected}")

    ## Now see what the device says.
    with MicArrayDevice(xe_path, quiet_xgdb=not self.print_xgdb, extra_xrun_args="--id 0") as dev:

      # Make sure we're talking to the correct application
      assert dev.param["channels"] == chans
      assert dev.param["s1.dec_factor"] == filter.s1.DecimationFactor
      assert dev.param["s1.tap_count"] == filter.s1.TapCount
      assert dev.param["s2.dec_factor"] == filter.s2.DecimationFactor
      assert dev.param["s2.tap_count"] == filter.s2.TapCount
      assert dev.param["frame_size"] == frame_size
      assert dev.param["use_isr"] == use_isr

      # If we're supposed to print filters, tell the device to do so
      if self.debug_print_filters: dev.send_command(DevCommand.PRINT_FILTERS.value)

      # Get the device's output
      device_output = dev.process_signal(sig)

      if self.print_output: print(f"Device output: {device_output}")

      dev.send_command(DevCommand.TERMINATE.value)

    # The second stage filter will usually yield exactly correct results, but
    # not always, because the 64-bit partial products of the inner product
    # (i.e.  filter_state[:] * filter_coef[:]) have a rounding-right-shift
    # applied to them prior to being summed.
    result_diff = np.max(np.abs(expected - device_output))
    print(f"result_diff = {result_diff}")
    if custom_filter_file:
      threshold = 12 # I think this is due to the longer stage2 filter in the custom filter (good_2_stage_filter_int.pkl) used in this test
    else:
      threshold = 4

    assert result_diff <= threshold, f"max diff between python and xcore mic array output ({result_diff}) exceeds threshold ({threshold})"

