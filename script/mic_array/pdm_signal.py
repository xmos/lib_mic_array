# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import os
import numpy as np

class PdmSignal(object):
  """
  Class represents an N-channel PDM signal. Basically a numpy.ndarray with some
  logic checks and helper functions.
  """

  def __init__(self, signal: np.ndarray):
    assert signal.ndim <= 2
    if signal.ndim == 1:
      signal = signal.reshape((1,len(signal)))
    assert np.all( np.logical_or((signal==1), (signal==-1)) )
    assert(signal.shape[0] in {1,2,4,8,16})
    self.signal = signal.astype(np.int32)

  @property
  def len(self):
    return self.signal.shape[1]

  def block_count(self, total_decimation_factor):
    return self.len // total_decimation_factor


  @staticmethod
  def random(chans: int, samps: int):
    assert(chans in {1, 2, 4, 8, 16})
    assert(samps % 32 == 0)

    N_bits = chans * samps
    N_bytes = N_bits // 8

    sig = os.urandom(N_bytes)
    sig = np.unpackbits(np.frombuffer(sig, dtype=np.uint8), 
                  bitorder='little').astype(int)
    sig = sig.reshape((chans,samps))
    sig = 1-(2*sig)
    return PdmSignal(sig)

  def to_binary(self) -> np.ndarray:
    """
    Convert the bipolar {-1,+1} PDM signal into a binary {0,1} signal, using the
    mapping: {+1 --> 0, -1 --> 1}
    """
    return (1-self.signal)//2

  def to_bytes(self, s2_dec_factor):
    """
    Convert PDM signal into sequence of words which is directly consumable by 
    the decimator

    Decimator expects a sequence of PDM data blocks, where each block contains
    chan_count*s2_dec_factor words of PDM data, and each block is formated as:

      uint32_t block[CHAN_COUNT][S2_DEC_FACTOR]

    where the channels are in-order and words within a channel are in order of
    occurance.

    Note that for each bit value in the result, 0 represents +1, and 1
    represents -1.
    """
    # first, convert to binary values
    sig = self.to_binary().astype(np.uint32)
    CHAN_COUNT = sig.shape[0]
    SAMP_COUNT = sig.shape[1]
    BLOCKS = SAMP_COUNT // (32 * s2_dec_factor)
    TOTAL_WORDS = SAMP_COUNT * CHAN_COUNT // 32
    sig = np.apply_along_axis(lambda x: np.dot(x, 2**np.arange(32,dtype=np.uint32)), 2,
                sig.reshape((CHAN_COUNT, SAMP_COUNT//32, 32)))
    sig = sig.transpose()
    sig = sig.reshape((BLOCKS, s2_dec_factor, CHAN_COUNT))
    sig = sig.transpose(0,2,1)
    sig = sig.reshape(TOTAL_WORDS)
    sig = sig.tobytes()
    return sig


  def to_bytes_interleaved(self):
    """
    Convert PDM signal into sequence of words which is directly consumable by 
    the mic array PdmRx

    Note that for each bit value in the result, 0 represents +1, and 1
    represents -1.
    """
    sig = self.to_binary()
    CHAN_COUNT = sig.shape[0]
    SAMP_COUNT = sig.shape[1]
    SPW = 32 // CHAN_COUNT

    sig = np.apply_along_axis(lambda x: np.dot(x, 2**np.arange(CHAN_COUNT)), 0, sig)
    sig = sig.reshape(SAMP_COUNT//SPW, SPW)
    
    return np.apply_along_axis(lambda x: np.dot(x, 
                2**(CHAN_COUNT * np.arange(SPW))), 1, sig).astype(np.int32).tobytes()
    
