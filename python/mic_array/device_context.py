# Copyright 2022-2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import subprocess
from . import xscope
from time import sleep

class DeviceContext(object):

  def __init__(self, xe_path, /, probes=[], extra_xrun_args="", runner="xrun", **kwargs):

    self.xe_path = xe_path

    if runner == "xrun":
      self.device_cmd = ["xrun", "--xscope", "--xscope-port", "localhost:10234"] + extra_xrun_args.split() + [self.xe_path]
    elif runner == "xgdb":
      self.device_cmd = [
        "xgdb", self.xe_path, "--quiet", "--batch", "--return-child-result",
        "-ex", "connect --reset --xscope --xscope-port localhost:10234",
        "-ex", "load",
        "-ex", "run",
        "-ex", "quit",
      ]
    else:
      raise ValueError(f"Unsupported device runner: {runner}")

    self.device_process = None
    self.quiet_xgdb = kwargs.get("quiet_xgdb", True)

    self.ep = xscope.Endpoint()

    self.probe_timeout = ( 10.0 if "probe_timeout" not in kwargs
                           else kwargs["probe_timeout"] )

    self.probes = { k: xscope.QueueConsumer(self.ep, k,
                        probe_timeout=self.probe_timeout) for k in probes }

    self.connect_retries = ( 5 if "connect_retries" not in kwargs
                             else kwargs["connect_retries"] )

  def _on_connect(self):
    pass # for subclasses to override

  def _stop_device_process(self, wait_for_exit=False):
    if self.device_process is None:
      return
    try:
      if wait_for_exit:
        self.device_process.wait(timeout=10)
      else:
        self.device_process.terminate()
        self.device_process.wait(timeout=5)
    except subprocess.TimeoutExpired:
      self.device_process.kill()
      self.device_process.wait()
    finally:
      self.device_process = None

  def __enter__(self):

    stdout = subprocess.DEVNULL if self.quiet_xgdb else None
    self.device_process = subprocess.Popen(self.device_cmd, stdout=stdout)

    try:
      for _ in range(self.connect_retries):
        c = self.ep.connect()
        if not c: break
        sleep(1)
        print("Retrying..")
      if c:
        print("Failed to connect to xgdb.")
        self.ep = None
        raise Exception("Failed to connect to xgdb.")
      self._on_connect()
    except:
      self._stop_device_process()
      raise
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    if self.ep is not None:
      try:    self.ep.disconnect()
      except: pass
    self._stop_device_process(wait_for_exit=exc_type is None)

  def send_bytes(self, data):
    if len(data) == 0:
      self.ep.publish(data)
      return

    while (len(data) > 0):
      self.ep.publish(data[:128])
      data = data[128:]

  def send_word(self, word):
    self.send_bytes(int(word).to_bytes(4,'little'))

  def probe_next(self, probe, count=1):
    return self.probes[probe].next(count)


