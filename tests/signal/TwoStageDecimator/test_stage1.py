# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
 
######
# Test: TwoStageDecimator stage 1 test
#
# This test is intended to make sure the first stage of the TwoStageDecimator is
# producing correct results. 
#
# Notes:
#  - This test assumes that the CMake targets for this app are all already
#    built.
#  - This test directly launches xgdb, and so the XTC tools must be on your
#    path.
#  - An appropriate xCore device must be connected to the host using xTag
#  - This test should be executed with pytest. To run it, navigate to the root
#    of your CMake build directory, and run:
#       > pytest path/to/this/dir/test_stage1.py
######

import sys, os, time
import numpy as np
from mic_array import filters
from mic_array.pdm_signal import PdmSignal
from decimator_device import DecimatorDevice
import pytest
from conftest import test_params, xe_file_path


class Test_Stage1(object):

  @pytest.fixture(autouse=True)
  def __init_case(self, request):
    np.set_printoptions(threshold=sys.maxsize,  
                        linewidth=80)
    self.print_out = request.config.getoption("print_output")

  def gen_filter(self, s2_tap_count, s2_dec_factor):
    # This test uses a random first stage filter. No arithmetic saturation is 
    # possible, regardless of what we pick.
    s1_coef = np.round(np.ldexp((np.random.random_sample(256) - 0.5), 15)).astype(np.int16)
    s1_filter = filters.Stage1Filter(s1_coef)
    
    # This test uses a simple pass-through filter for the second stage
    #   decimator. (i.e.  b = [1.0, 0, 0, 0, 0, ...]) The output from the full
    # decimator should then be exactly what was output by the first stage, with
    # (s2_dec_factor-1) of every (s2_dec_factor) samples dropped.
    s2_coef = np.zeros((s2_tap_count), dtype=np.int32)
    s2_coef[0] = 0x40000000
    s2_filter = filters.Stage2Filter(s2_coef, s2_dec_factor)
    assert s2_filter.Shr == 0

    return filters.TwoStageFilter(s1_filter, s2_filter)
    

  @pytest.mark.parametrize('xe_param', test_params)
  def test_stage1(self, request, xe_param):

    chans, s2_df, s2_taps = xe_param
    
    print(f"\nParams[Channels: {chans}; S2 Dec Factor: {s2_df}; S2 Tap Count: {s2_taps}]")

    xe_path = xe_file_path(xe_param, request.config.getoption("build_dir"))

    assert os.path.isfile(xe_path)

    blocks = request.config.getoption("blocks")

    # Generate random filter
    filter = self.gen_filter(s2_taps, s2_df)

    # Generate random PDM signal
    sig = PdmSignal.random(chans, 32 * blocks * filter.s2.DecimationFactor)

    # Compute the expected output
    expected = filter.Filter(sig.signal)

    if self.print_out: print(f"Expected output: {expected}")

    ## Now see what the device says.
    with DecimatorDevice(xe_path) as dev:

      assert dev.param["channels"] == chans
      assert dev.param["s1.dec_factor"] == 32
      assert dev.param["s1.tap_count"] == 256
      assert dev.param["s2.dec_factor"] == s2_df
      assert dev.param["s2.tap_count"] == s2_taps

      # Get the device's output
      device_output = dev.process_signal(filter, sig)

      if self.print_out: print(f"Device output: {device_output}")

      # The second stage filter will usually yield exactly correct results, but
      # not always, because the 64-bit partial products of the inner product 
      # (i.e.  filter_state[:] * filter_coef[:]) have a rounding-right-shift 
      # applied to them prior to being summed.
      result_diff = np.max(np.abs(expected - device_output))
      assert result_diff <= 1

