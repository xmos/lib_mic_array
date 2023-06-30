# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import os, signal, subprocess
from . import xscope
from time import sleep

class DeviceContext(object):
  
  XRUN_CMD_BASE = ('xrun', '--xscope-realtime', '--xscope-port','localhost:10234')

  def __init__(self, xe_path, /, probes=[], **kwargs):
    
    self.xe_path = xe_path

    self.xrun_cmd = list(DeviceContext.XRUN_CMD_BASE) + [self.xe_path]
    self.xrun = None

    self.ep = xscope.Endpoint()

    self.probe_timeout = ( 10.0 if "probe_timeout" not in kwargs
                           else kwargs["probe_timeout"] )

    self.probes = { k: xscope.QueueConsumer(self.ep, k, 
                        probe_timeout=self.probe_timeout) for k in probes }

    self.connect_retries = ( 5 if "connect_retries" not in kwargs 
                             else kwargs["connect_retries"] )

  def _on_connect(self):
    pass # for subclasses to override

  def __enter__(self):
    

    self.xrun = subprocess.Popen(self.xrun_cmd, stdout=subprocess.DEVNULL)
    sleep(3)

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
      self.xrun.terminate()
      self.xrun = None
      raise
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    if self.ep is not None:
      try:    self.ep.disconnect()
      except: pass
    if self.xrun is not None:
      try :
        self.xrun.terminate()
        self.xrun = None
      except: 
        pass

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

    
