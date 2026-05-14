# Copyright 2022-2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

######
# Test: BasicMicArray test
#
# This test is intended to ensure the mic array implementation, invoked via
# the default and custom filter APIs appears to produce the expected results.
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

MAX_DIFF_TH = 12

with open(Path(__file__).parent / "test_params.json") as f:
    params = json.load(f)

smoke_test_chans = [4] # Since 8n-16frame is currently disabled. See https://github.com/xmos/lib_mic_array/issues/288
smoke_test_frame_sz = [1, 16]
def ma_test_uncollect(config, chans, frame_size, use_isr, one_mic_override, fs):
  """Determine whether to skip test cases based on test level.

  Returns True to uncollect (skip), False to collect (run).

  Smoke tests: Collect only 4ch with 1 or 16 frame sizes.
  Nightly tests with one_mic_override=0: Collect all configurations.
  Nightly tests with one_mic_override=1: Collect only 4ch/16frame with custom filters and 16kHz.
  """
  level = config.getoption("level")
  if level == "smoke":
    if((chans in smoke_test_chans) and (frame_size in smoke_test_frame_sz)):
      return False
    else:
      return True # uncollect everything other than 4ch with 1 or 16 frame sizes
  else: # nightly
    if one_mic_override == 0: # Collect everything for which one_mic_override=0
      return False
    else: # one_mic_override = 1
      # collect only one config (4ch, 16 frame), for the custom pkl file and one of the supported rates (16000) to keep the test time reasonable
      # No particular reason why this specific config was selected
      if((chans == 4) and (frame_size == 16)):
        if (not isinstance(fs, int)): # custom pkl file
          return False
        elif fs == 16000:
          return False
        else:
          # If we've reached here, uncollect!
          return True
      else:
        # If we've reached here, uncollect!
        return True

class Test_BasicMicArray(MicArraySharedBase):
  @pytest.mark.uncollect_if(func=ma_test_uncollect)
  @pytest.mark.parametrize("chans", params["N_MICS"], ids=[f"{nm}n_mics" for nm in params["N_MICS"]])
  @pytest.mark.parametrize("frame_size", params["FRAME_SIZE"], ids=[f"{fs}frame" for fs in params["FRAME_SIZE"]])
  @pytest.mark.parametrize("use_isr", params["USE_ISR"], ids=[f"{ui}isr" for ui in params["USE_ISR"]])
  @pytest.mark.parametrize("one_mic_override", params["1MIC_OVERRIDE"], ids=[f"{ui}mo" for ui in params["1MIC_OVERRIDE"]])
  @pytest.mark.parametrize("fs", params["SAMP_FREQ"], ids=[f"{s}" for s in params["SAMP_FREQ"]])
  def test_BasicMicArray(self, request, chans, frame_size, use_isr, one_mic_override, fs):
    cwd = Path(request.fspath).parent

    custom_filter_file = None
    if not isinstance(fs, int): # fs must contain the name of the filter .pkl file
      custom_filter_file = fs
      cfg = f"{chans}ch_{frame_size}smp_{use_isr}isr_{one_mic_override}mo_customfs"
    else:
      cfg = f"{chans}ch_{frame_size}smp_{use_isr}isr_{one_mic_override}mo_{fs}fs"

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
    stg1_output_words_per_frame = int(filter.DecimationFactor/filter.s1.DecimationFactor)
    samp_per_frame = 32 * stg1_output_words_per_frame * frame_size

    # Total PDM samples (per channel)
    samp_total = samp_per_frame * frames

    if one_mic_override == 1:
      chans = 1 # Override chans to 1

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

    exp_size = expected.size
    dev_size = device_output.size
    print(f"expected size: {exp_size}, device output size: {dev_size}")

    assert result_diff <= MAX_DIFF_TH, f"max diff between python and xcore mic array output ({result_diff}) exceeds MAX_DIFF_TH ({MAX_DIFF_TH})"
    assert exp_size == dev_size, f"Expected and device output sizes differ"


  @pytest.mark.parametrize("chans", [1, 2], ids=["1mic_override", "2mic"])
  def test_BasicMicArrayOneStageFilter(self, request, chans):
    """Verify sample-level correctness of the 1-stage filter path using small_768k_to_12k_filter_int.pkl.

    Tests two configurations of the stage-1-only decimator:
    - chans=1: 1-mic override enabled (MIC_ARRAY_CONFIG_MIC_COUNT set > 1 in the build, overridden at runtime to 1).
    - chans=2: no override, 2-mic normal operation.

    Generates random PDM input, computes the expected output via the Python stage-1 filter,
    then compares against the xcore device output sample-by-sample within a fixed tolerance.
    """
    cwd = Path(request.fspath).parent
    filter = self.filter(Path(__file__).parent / "small_768k_to_12k_filter_int.pkl")

    stg1_output_words_per_frame = int(filter.DecimationFactor / filter.s1.DecimationFactor)
    assert stg1_output_words_per_frame == 2

    samp_per_frame = 32
    frames = request.config.getoption("frames")
    decimator_stgs = 1
    # --- num decimator stages dependent behaviour ---
    stg1_only = (decimator_stgs == 1)
    output_frame_size = 2 if stg1_only else 1
    samp_total = samp_per_frame * frames * output_frame_size
    device_output_delay_samps = 0 if stg1_only else 1
    sample_override = frames * output_frame_size if stg1_only else None
    # -------------------------------------------------

    sig = PdmSignal.random(chans, samp_total)

    expected = filter.Filter(sig.signal, stg1_only=stg1_only)

    if self.print_output:
      print(f"Expected output: {expected}")

    assert chans in [1,2]
    if chans == 1:
      cfg = f"{decimator_stgs}stg_filter_1mic_override"
    elif chans == 2:
      cfg = f"{decimator_stgs}stg_filter"

    xe_path = f"{cwd}/bin/{cfg}/test_ma_{cfg}.xe"
    assert Path(xe_path).exists(), f"Cannot find {xe_path}"

    with MicArrayDevice(
      xe_path,
      quiet_xgdb=not self.print_xgdb,
      extra_xrun_args="--id 0"
    ) as dev:

      assert dev.param["channels"] == chans
      assert dev.param["s1.dec_factor"] == filter.s1.DecimationFactor
      assert dev.param["s1.tap_count"] == filter.s1.TapCount
      if decimator_stgs > 1:
        assert dev.param["s2.dec_factor"] == filter.s2.DecimationFactor
        assert dev.param["s2.tap_count"] == filter.s2.TapCount
      assert dev.param["frame_size"] == output_frame_size
      assert dev.param["use_isr"] == 0

      if self.debug_print_filters:
        dev.send_command(DevCommand.PRINT_FILTERS.value)

      device_output = dev.process_signal(sig, sample_count_override=sample_override)

      if self.print_output:
        print(f"Device output: {device_output}")

      dev.send_command(DevCommand.TERMINATE.value)

    end = -device_output_delay_samps or None
    start = device_output_delay_samps

    exp_size = expected[:, :end].size
    dev_size = device_output[:, start:].size
    result_diff = np.max(np.abs(expected[:, :end] - device_output[:, start:]))

    print(f"result_diff = {result_diff}")
    print(f"expected size: {exp_size}, device output size: {dev_size}")

    assert exp_size == dev_size, (
      f"Expected and device output sizes differ"
    )
    assert result_diff <= MAX_DIFF_TH, (
      f"max diff between python and xcore mic array output ({result_diff}) "
      f"exceeds MAX_DIFF_TH ({MAX_DIFF_TH})"
    )
