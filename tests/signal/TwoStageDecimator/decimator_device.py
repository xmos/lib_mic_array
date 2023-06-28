# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
 

import numpy as np
from mic_array.device_context import DeviceContext
from mic_array import filters
from mic_array.pdm_signal import PdmSignal


class DecimatorDevice(DeviceContext):
  
  def __init__(self, xe_path, /, **kwargs):
    super().__init__(xe_path, probes=["meta_out", "data_out"], **kwargs)

    self.channels = None # unknown initially

  def next_data(self, count=1):
    return self.probe_next("data_out", count=count)

  def next_meta(self, count=1):
    return self.probe_next("meta_out", count=count)

  def _on_connect(self):
    self.param = {
      "channels": self.next_meta(),
      "s1.tap_count": self.next_meta(),
      "s1.dec_factor": self.next_meta(),
      "s2.tap_count": self.next_meta(),
      "s2.dec_factor": self.next_meta(),
    }
    self.channels = self.param["channels"]

  def send_stage1_filter(self, s1_filter: filters.Stage1Filter):
    xcore_coef = s1_filter.ToXCoreCoefArray().tobytes()
    self.send_bytes(xcore_coef)

  def send_stage2_filter(self, s2_filter: filters.Stage2Filter):
    xcore_coef = s2_filter.Coef.tobytes()
    self.send_bytes(xcore_coef)
    self.send_word(s2_filter.Shr)

  def send_decimator(self, filter: filters.TwoStageFilter):
    self.send_stage1_filter(filter.s1)
    self.send_stage2_filter(filter.s2)

  def process_signal(self, filter: filters.TwoStageFilter, 
                           signal: PdmSignal):

    blocks = signal.block_count(filter.DecimationFactor)

    self.send_decimator(filter)
    self.send_word(blocks)

    sig_bytes = signal.to_bytes(filter.s2.DecimationFactor)
    device_output = np.zeros((self.channels, blocks), dtype=np.int32)

    # Bytes per block
    L = self.channels * filter.s2.DecimationFactor * 4
    for k in range(blocks):
      # Send one block at a time
      self.send_bytes(sig_bytes[k*L:(k+1)*L])
      # Listen for response (should be ctx.channels words)
      device_output[:,k] = self.next_data(count=self.channels)
    
    return device_output


  