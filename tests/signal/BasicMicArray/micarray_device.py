# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
 

import numpy as np
from mic_array.device_context import DeviceContext
from mic_array import filters
from mic_array.pdm_signal import PdmSignal


class MicArrayDevice(DeviceContext):
  
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
      "frame_size": self.next_meta(),
      "use_isr" : self.next_meta()
    }

  def send_command(self, cmd_id):
    cmd_id = np.int32(cmd_id)
    # First, send 0 bytes to signal that a command follows
    self.send_bytes(b"")
    # Then, send the command ID
    self.send_word(cmd_id)

  def process_signal(self, signal: PdmSignal):

    # First, send the entire signal to the device. Any output it sends over the
    # data probe will get queued up by our parent class, so that it doesn't back
    # up the device. We can just read out all the output afterwards.

    # Note that this time we should be sending the signal in the format expected
    # by the PDM rx service, NOT in the form expected by the decimator. That 
    # really just means the channels need to be interleaved.
    sig_bytes = signal.to_bytes_interleaved()
    self.send_bytes(sig_bytes)

    sample_count = signal.len // ( 32 * self.param["s2.dec_factor"] )
    device_output = np.zeros((self.param["channels"], sample_count), dtype=np.int32)

    # Device sends output as if it had shape (sample_count, channel_count)
    for k in range(sample_count):
      # Listen for response (should be ctx.channels words)
      device_output[:,k] = self.next_data(count=self.param["channels"])

    return device_output


  