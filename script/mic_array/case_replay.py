"""
Module to make it easier to take replay failing test cases.

CaseReplay class is instantiated in one of three modes -- do-nothing (default), 
save-vectors, or load-vectors.

Do-nothing does nothing with signals -- neither saves nor loads them. Save-vectors
will store a case's random vectors/values so that they can be loaded on a subsequent
run. Load-vectors loads them from file.
"""
import numpy as np
import pickle, os, sys, enum

class ReplayMode(enum.Enum):
  DO_NOTHING = 0
  SAVE_VECTORS = 1
  LOAD_VECTORS = 2

class NoSignalToLoadException(Exception):
  pass


def InitReplay(case_name: str, mode: ReplayMode = ReplayMode.DO_NOTHING):
  return CaseReplay(case_name, mode)

class CaseReplay(object):
  CASE_DIR = f"./case_replay.local/"

  def __init__(self, case_name: str, mode: ReplayMode = ReplayMode.DO_NOTHING):
    self.case_name = case_name
    self.case_path = os.path.join(CaseReplay.CASE_DIR, self.case_name)
    self.vectors = dict()
    self.mode = mode

  def __enter__(self):
    # Nothing to do on entry unless we're loading.
    if self.mode == ReplayMode.LOAD_VECTORS:
      os.makedirs(CaseReplay.CASE_DIR, exist_ok=True) 
      if not os.path.exists(self.case_path):
        raise NoSignalToLoadException(f"File {self.case_path} does not exist.")

      with open(self.case_path, 'rb') as file_in:
        self.vectors = pickle.load(file_in)
    return self
  
  def __exit__(self, exc_type, exc_val, exc_tb):
    # Nothing to do on exit unless we're saving.
    if self.mode == ReplayMode.SAVE_VECTORS:
      os.makedirs(CaseReplay.CASE_DIR, exist_ok=True) 
      with open(self.case_path, 'wb') as file_out:
        pickle.dump(self.vectors, file_out)

  def apply(self, vec_name: str, vector):
    """
    The model here is to call apply() on a signal in a test case *after* it has
    already been given a random value. In the test case, the signal variable is
    assigned the result of that call. If we're in load-vectors mode, it'll 
    replace the signal with the value in the saved file (if it exists; otherwise
    an exception will be raised). If we're in save-vectors mode, the signal will
    be added to the dictionary to be saved on __exit__(), and then returned
    unmodified. In do-nothing mode it will just be returned unmodified.
    """
    if self.mode == ReplayMode.LOAD_VECTORS:  
      if vec_name not in self.vectors:
        raise NoSignalToLoadException(f"Vector named {vec_name} not found for case {self.case_name}.")
      vector = self.vectors[vec_name]
    
    elif self.mode == ReplayMode.SAVE_VECTORS:
      self.vectors[vec_name] = vector

    return vector