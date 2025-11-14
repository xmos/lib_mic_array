# Copyright 2022-2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import os
import numpy as np
from scipy import signal
from pcm_to_pdm import up_down_ratio, delta_sigma_5th_order
from audio_generation import get_sine
import random

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

    sig = bytes(random.randint(0, 255) for _ in range(N_bytes))

    sig = np.unpackbits(np.frombuffer(sig, dtype=np.uint8),
                  bitorder='little').astype(int)
    sig = sig.reshape((chans,samps))
    sig = 1-(2*sig)
    return PdmSignal(sig)

  @staticmethod
  def sine(
    f_tone: list,
    amplitude: list,
    fs_pcm: int,
    duration: float,
    fs_pdm=3_072_000
    ):
    """
    Generate multi-channel PCM sine tones and convert them into 1-bit PDM
    streams using a 5th-order delta-sigma modulator.

    Each channel contains a single sine tone specified by `f_tone[i]`
    with amplitude `amplitude[i]`.
    All channels are first synthesized as PCM, then upsampled to the PDM rate,
    and finally delta-sigma modulated to produce 1-bit PDM output.

    Parameters
    ----------
    f_tone : list of float
        List of sine-wave frequencies in Hz. One frequency per output channel.
        Must be a non-empty list.
    amplitude : list of float
        List of amplitudes corresponding to each frequency. Must be the same
        length as `f_tone`.
    fs_pcm : int
        PCM sampling rate in Hz used for generating the initial PCM sine waves.
    duration : float
        Duration of the generated signals in seconds.
    fs_pdm : int, optional
        Target PDM sample rate in Hz (default is 3,072,000).

    Returns
    -------
    PdmSignal
        Object holding the generated 1-bit PDM data with shape
        ``(num_channels, pdm_length)``.
    numpy.ndarray
        Numpy float64 array containing the PCM signals before upsampling

    Raises
    ------
    ValueError
        If `f_tone` or `amplitude` are empty, not lists, or have mismatched
        lengths.
    """
    # ---- Validation ----
    if not isinstance(f_tone, list) or len(f_tone) == 0:
        raise ValueError("f_tone must be a non-empty list")

    if not isinstance(amplitude, list) or len(amplitude) == 0:
        raise ValueError("amplitude must be a non-empty list")

    if len(f_tone) != len(amplitude):
        raise ValueError("f_tone and amplitude must have the same length")

    upsample_ratio , downsample_ratio = up_down_ratio(fs_pcm, fs_pdm)

    # ---- Generate all PCM signals ----
    pcm_list = []
    for f, a in zip(f_tone, amplitude):
      s = get_sine(duration, [f], amplitudes=[a], sample_rate=fs_pcm)
      pcm_list.append(s)
    pcm = np.vstack(pcm_list)

    # ---- Upsample all PCM signals ----
    upsampled_list = []
    for s in pcm:
      upsampled = signal.resample_poly(s, upsample_ratio, downsample_ratio)
      upsampled_list.append(upsampled)
    upsampled_pcm = np.vstack(upsampled_list)

    # ---- Delta sigma modulate ----
    output_length = len(pcm[0])*upsample_ratio // downsample_ratio
    pdm_samples = np.empty((len(f_tone), output_length))
    for i in range(len(f_tone)):
      pdm_samples[i] = delta_sigma_5th_order(upsampled_pcm[i], output_length)

    return PdmSignal(pdm_samples), pcm


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


