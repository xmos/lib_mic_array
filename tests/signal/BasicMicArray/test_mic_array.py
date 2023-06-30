# Copyright 2022 XMOS LIMITED.
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

import sys, os, pickle
import numpy as np
from mic_array import filters
from mic_array.pdm_signal import PdmSignal
from micarray_device import MicArrayDevice
import pytest
from conftest import test_params, xe_file_path, FLAGS, DevCommand


class Test_BasicMicArray(object):

  DEFAULT_FILTERS_FILE = os.path.join(os.path.dirname(__file__), "default_filters.pkl")

  @pytest.fixture(autouse=True)
  def __init_case(self, request):
    np.set_printoptions(threshold=sys.maxsize,  
                        linewidth=80)

  @pytest.fixture(autouse=True)
  def __init_flags(self, request):
    for f in FLAGS:
      fs = f.replace("-","_")
      op = request.config.getoption(fs)
      self.__dict__[fs] = op
  
  def default_filter(self):
    # load the default filters from the pkl file. 
    with open(self.DEFAULT_FILTERS_FILE, "rb") as filt_file:
      stage1, stage2 = pickle.load(filt_file)
    
    s1_coef, s1_df = stage1
    s2_coef, s2_df = stage2

    # if the stage1 filter is not 256 taps, then we need to pad it out to 256
    if len(s1_coef) < 256:
      s1_coef = np.pad(s1_coef, (0, 256 - len(s1_coef)), 'constant')

    assert s1_df == 32
    assert s2_df == 6
    assert len(s1_coef) == 256
    assert len(s2_coef) == 64

    s1_filter = filters.Stage1Filter(s1_coef, s1_df)
    s2_filter = filters.Stage2Filter(s2_coef, s2_df)

    if self.debug_print_filters:
      # print stage1 as uint32 so that it is easy to compare to the device
      s1_coef_bytes = s1_filter.ToXCoreCoefArray().tobytes()
      s1_coef_words = np.frombuffer(s1_coef_bytes, dtype=np.uint32)
      print(f"Stage1 Filter: {repr(np.array([hex(x) for x in s1_coef_words]))}")

      print(f"Stage2 Filter: {np.array([('0x%08X' % np.uint32(x)) for x in s2_filter.CoefInt32])}")
      print(f"Stage2 Filter shr: {s2_filter.Shr}")

    return filters.TwoStageFilter(s1_filter, s2_filter)
    

  @pytest.mark.parametrize('xe_param', test_params)
  def test_BasicMicArray(self, request, xe_param):

    chans, frame_size, use_isr = xe_param
    
    print(f"\nParams[Channels: {chans}; Frame Size: {frame_size}; Use ISR: {use_isr}]")

    xe_path = xe_file_path(xe_param, request.config.getoption("build_dir"))

    assert os.path.isfile(xe_path), f"Required executable does not exist ({xe_path})"

    frames = request.config.getoption("frames")

    # Generate random filter
    filter = self.default_filter()

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
    with MicArrayDevice(xe_path, quiet_xgdb=not self.print_xgdb) as dev:

      # Make sure we're talking to the correct application
      assert dev.param["channels"] == chans
      assert dev.param["s1.dec_factor"] == 32
      assert dev.param["s1.tap_count"] == 256
      assert dev.param["s2.dec_factor"] == 6
      assert dev.param["s2.tap_count"] == 65
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
    assert result_diff <= 4

