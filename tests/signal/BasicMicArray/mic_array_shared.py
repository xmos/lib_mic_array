# Copyright 2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import sys, pickle
import numpy as np
from mic_array import filters
import pytest
from conftest import FLAGS
from pathlib import Path

class MicArraySharedBase:
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

  def default_filter(self, fs):
    assert fs in [16000, 32000, 48000]
    if fs == 16000:
      self.DEFAULT_FILTERS_FILE = Path(__file__).parent / "default_filters.pkl"
    elif fs == 32000:
      self.DEFAULT_FILTERS_FILE = Path(__file__).parent / "good_32k_filter_int.pkl"
    elif fs == 48000:
      self.DEFAULT_FILTERS_FILE = Path(__file__).parent / "good_48k_filter_int.pkl"

    # load the default filters from the pkl file.
    with open(self.DEFAULT_FILTERS_FILE, "rb") as filt_file:
      stage1, stage2 = pickle.load(filt_file)

    s1_coef, s1_df = stage1
    s2_coef, s2_df = stage2

    # if the stage1 filter is not 256 taps, then we need to pad it out to 256
    if len(s1_coef) < 256:
      s1_coef = np.pad(s1_coef, (0, 256 - len(s1_coef)), 'constant')

    s1_filter = filters.Stage1Filter(s1_coef, s1_df)
    s2_filter = filters.Stage2Filter(s2_coef, s2_df)

    if self.debug_print_filters:
      # Print stage1 filter
      # print stage1 as uint32 so that it is easy to compare to the device
      s1_coef_bytes = s1_filter.ToXCoreCoefArray().tobytes()
      s1_coef_words = np.frombuffer(s1_coef_bytes, dtype=np.uint32)

      s1_formatted = [ f"0x{x:08X}" for x in s1_coef_words]
      print(f"Stage1 filter length: {len(s1_coef_words)*2} 16bit coefs -> {len(s1_coef_words)} 32b words")
      print("Stage1 Filter:")
      initial_count = (len(s1_formatted)//4)*4
      for i in range(0, initial_count, 4): # print 4 per row
        print("  " + "  ".join(s1_formatted[i:i+4]))

      remaining_s1 = s1_formatted[initial_count:]
      if len(remaining_s1):
        print("  " + "  ".join(remaining_s1))

      print("\n")

      # Print stage2 filter
      s2_formatted = [f"0x{np.uint32(x):08X}" for x in s2_filter.Coef]
      print(f"Stage2 filter length: {len(s2_filter.Coef)}")
      print(f"Stage2 Filter:")

      initial_count = (len(s2_formatted)//4)*4
      for i in range(0, initial_count, 4): # print 4 per row
        print("  " + "  ".join(s2_formatted[i:i+4]))

      remaining_s2 = s2_formatted[initial_count:]
      if len(remaining_s2):
        print("  " + "  ".join(remaining_s2))
      print(f"Stage2 Filter shr: {s2_filter.Shr}")

    return filters.TwoStageFilter(s1_filter, s2_filter)

