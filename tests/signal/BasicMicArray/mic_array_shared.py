# Copyright 2025-2026 XMOS LIMITED.
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

  def print_two_stage_filter(self, s1_filter, s2_filter):
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


  def get_default_filter(self, fs):
    assert fs in [16000, 32000, 48000]
    if fs == 16000:
      return Path(__file__).parent / "good_2_stage_filter_int.pkl"
    elif fs == 32000:
      return Path(__file__).parent / "good_32k_filter_int.pkl"
    elif fs == 48000:
      return Path(__file__).parent / "good_48k_filter_int.pkl"

  def filter(self, filter_pkl_file):
    # load the default filters from the pkl file.
    stg_filters = filters.load(filter_pkl_file)

    assert len(stg_filters) in [2, 3], f"Invalid number of filter stages: {len(stg_filters)}"

    if self.debug_print_filters and (len(stg_filters) == 2):
      self.print_two_stage_filter(stg_filters[0], stg_filters[1])

    if len(stg_filters) == 2:
      return filters.TwoStageFilter(stg_filters[0], stg_filters[1])
    else:
      return filters.ThreeStageFilter(stg_filters[0], stg_filters[1], stg_filters[2])
