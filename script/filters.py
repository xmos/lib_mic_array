
import numpy as np
import pickle as pkl
import util


def VLMACCR1(vC: np.ndarray, mem: np.ndarray, acc = 0, **kwargs) -> np.int32:
  # vC and mem should both be binary {0,1} vectors that are 256 elements
  assert vC.ndim == 1
  assert mem.ndim == 1
  assert len(vC) == 256
  assert len(mem) == 256

  q = np.int(1)*(~(vC == mem))
  popcount_xor = np.sum(q)
  return acc + (128 - popcount_xor)



class Stage1Filter(object):

  INT16_MAX_COEFFICIENT = 32766
  BLOCK_SIZE = 256

  def __init__(self, coefs: np.ndarray, decimation_factor: int):

    assert (coefs.ndim == 1), "Stage1Filter coefs must be a single dimensional ndarray"
    assert (len(coefs) % Stage1Filter.BLOCK_SIZE == 0), f"Stage1Filter must have a multiple of 256 coefficients ({len(coefs)})"

    t = np.argmax(np.abs(coefs))

    assert (np.abs(coefs[t]) <= 1.0), "Stage1Filter coefficients must be scaled to the range [-1.0, 1.0]"

    # The decimation factor
    self.dec_factor = decimation_factor

    # The coefficients themselves
    self.coefs = coefs

    # The scale factor for scaling to int16
    self.scale_int16 = Stage1Filter.INT16_MAX_COEFFICIENT / self.coefs[t]

    # The int16 filter coefficients
    # self.scale_int16 = (Stage1Filter.INT16_MAX_COEFFICIENT * (1 if coefs[t] >= 0 else -1)) / coefs[t]
    self.coefs_int16 = np.round(self.scale_int16 * self.coefs).astype(np.int16)

    # The bipolar {-1,1} filter coefficient representation
    self.coefs_bipolar = util.int16_vect_to_bipolar_matrix(self.coefs_int16, util.int16_dual)

    # The binary {1,0} filter coefficient representation
    #  (note that the binary matrix is from the bipolar transposed)
    self.coefs_binary = util.bipolar_to_binary(self.coefs_bipolar.T)

  @property
  def DecimationFactor(self):
    return self.dec_factor

  @property
  def TapCount(self):
    return len(self.coefs)
  
  @property
  def BlockCount(self):
    return len(self.coefs) // Stage1Filter.BLOCK_SIZE

  @property
  def Coef(self):
    return self.coefs

  @property
  def CoefInt16(self):
    return self.coefs_int16

  @property
  def ScaleInt16(self):
    return self.scale_int16
  
  @property
  def CoefBipolar(self):
    return self.coefs_bipolar
  
  @property
  def CoefBinary(self):
    return self.coefs_binary

  def FilterFloat(self, pdm_signal: np.ndarray, /, binary=False) -> np.ndarray:
    assert (pdm_signal.ndim == 1), "pdm_signal must be a 1D array"
    if binary: pdm_signal = 1 - 2*pdm_signal

    Q = self.DecimationFactor
    w = (self.TapCount - Q) // Q
    N_pcm = (len(pdm_signal) // Q) - w

    coefs = self.Coef.astype(np.float)
    res = np.zeros(N_pcm, dtype=np.float)

    for k in range(N_pcm):
      x = pdm_signal[Q*k:Q*k+self.TapCount]
      res[k] = np.dot( x, coefs )
    
    return res
  
  def FilterInt16(self, pdm_signal: np.ndarray, /, binary=False) -> np.ndarray:
    assert (pdm_signal.ndim == 1), "pdm_signal must be a 1D array"
    if binary: pdm_signal = 1 - 2*pdm_signal

    Q = self.DecimationFactor
    w = (self.TapCount - Q) // Q
    N_pcm = (len(pdm_signal) // Q) - w

    coefs = self.CoefInt16.astype(np.int32)
    res = np.zeros(N_pcm, dtype=np.int32)

    for k in range(N_pcm):
      x = pdm_signal[Q*k:Q*k+self.TapCount]
      res[k] = np.dot( x, coefs )
    
    return res
  
  def FilterBipolar(self, pdm_signal: np.ndarray, /, binary=False) -> np.ndarray:
    assert (pdm_signal.ndim == 1), "pdm_signal must be a 1D array"
    if binary: pdm_signal = 1 - 2*pdm_signal

    Q = self.DecimationFactor
    w = (self.TapCount - Q) // Q
    N_pcm = (len(pdm_signal) // Q) - w

    # (16 x self.TapCount) matrix
    coefs = self.CoefBipolar.astype(np.int32).T
    res = np.zeros(N_pcm, dtype=np.int32)

    for k in range(N_pcm):
      x = pdm_signal[Q*k:Q*k+self.TapCount]

      D = np.matmul( coefs, x ) // 2
      res[k] = np.dot( util.int16_dual, D )
    
    return res
    
  
  def FilterXCore(self, pdm_signal: np.ndarray, /, binary=True) -> np.ndarray:
    assert (pdm_signal.ndim == 1), "pdm_signal must be a 1D array"

    # change PDM signal to binary if needed
    if not binary: pdm_signal = (1 - pdm_signal)/2

    Q = self.DecimationFactor
    R = Stage1Filter.BLOCK_SIZE
    w = (self.TapCount - Q) // Q
    N_pcm = (len(pdm_signal) // Q) - w

    # (16 x self.TapCount) matrix
    coefs = self.CoefBinary.astype(np.int32)
    res = np.zeros(N_pcm, dtype=np.int32)

    for k in range(N_pcm):

      x = pdm_signal[Q*k:Q*k+self.TapCount]
      
      D = np.zeros(16, dtype=np.int32)
      for i in range(16):
        for j in range(self.BlockCount):
          D[i] = VLMACCR1(x, coefs[i,R*j:R*j+R], D[i])
      
      print(f"int16_dual: {util.int16_dual}")
      print(f"D: {D}")
      res[k] = np.dot(util.int16_dual, D)

    return res

  def ToXCoreCoefArray(self):

    B = self.CoefBinary
    B = B.reshape((B.size // 256, 8, 32)).astype(np.uint32)
    B = np.flip(B, axis=1)
    B = np.flip(B, axis=2)
    B = B.reshape((B.size // 32, 32))
    N = B.shape[0]
    y = np.zeros(N, dtype=np.uint32)
    
    F = (2**np.arange(32)).astype(np.uint32)[::-1]
    
    for k in range(N):
      y[k] = np.dot(F, B[k,:])
    
    return y





class Stage2Filter(object):

  INT32_MAX_COEFFICIENT = (2**31)-1

  def __init__(self, coefs: np.ndarray, decimation_factor: int):

    assert (coefs.ndim == 1), "Stage2Filter coefs must be a single dimensional ndarray"

    t = np.argmax(np.abs(coefs))

    assert (np.abs(coefs[t]) <= 1.0), "Stage2Filter coefficients must be scaled to the range [-1.0, 1.0]"

    # The decimation factor
    self.dec_factor = decimation_factor

    # The coefficients themselves
    self.coefs = coefs

    # The scale factor for scaling to int32
    self.scale_int32 = Stage2Filter.INT32_MAX_COEFFICIENT / self.coefs[t]

    # The int32 filter coefficients
    self.coefs_int32 = np.round(self.scale_int32 * self.coefs).astype(np.int32)

    # The right-shift required for fixed-point output scaling
    #  (the 0x7FFFFF00 is the largest value a 1-block Stage1 filter can output)
    max_samp_out = np.dot( np.int64( 0x7FFFFF00) * np.sign(self.coefs_int32).astype(np.int64), 
                           np.round(self.coefs_int32 / 2**30).astype(np.int64) )
    frac_shr = np.log2(max_samp_out) - 30
    self.shr_int32 = np.int(np.floor(frac_shr))


  @property
  def DecimationFactor(self):
    return self.dec_factor

  @property
  def TapCount(self):
    return len(self.coefs)

  @property
  def Coef(self):
    return self.coefs

  @property
  def CoefInt32(self):
    return self.coefs_int32

  @property
  def ScaleInt32(self):
    return self.scale_int32
  
  @property
  def ShrInt32(self):
    return self.shr_int32
  

  def FilterFloat(self, signal_in: np.ndarray) -> np.ndarray:
    assert (signal_in.ndim == 1), "signal_in must be a 1D array"
    
    Q = self.DecimationFactor
    w = (self.TapCount - Q) // Q
    N = (len(signal_in) // Q) - w

    coefs = self.Coef.astype(np.float)
    res = np.zeros(N, dtype=np.float)

    for k in range(N):
      x = signal_in[Q*k:Q*k+self.TapCount]
      res[k] = np.dot( x, coefs )
    
    return res
  
  def FilterInt32(self, signal_in: np.ndarray) -> np.ndarray:
    assert (signal_in.ndim == 1), "signal_in must be a 1D array"
    assert (signal_in.dtype == np.int32), "signal_in must have dtype==np.int32"
    
    Q = self.DecimationFactor
    w = (self.TapCount - Q) // Q
    N = (len(signal_in) // Q) - w

    coefs = self.CoefInt32.astype(np.int64)
    res = np.zeros(N, dtype=np.int32)

    for k in range(N):
      x = signal_in[Q*k:Q*k+self.TapCount]
      p = np.dot(x, coefs)
      res[k] = np.int32(np.round( p * 2**(-30-self.shr_int32) ))
    
    return res
  



def load(coef_file: str, /, truncate_s1=False):

  with open(coef_file, "rb") as pkl_file:
    # Split the pickled data into the stage1 and stage2 values
    stage1, stage2 = pkl.load(pkl_file)

  if truncate_s1:
    p = len(stage1[0]) % Stage1Filter.BLOCK_SIZE
    stage1[0] = stage1[0][:-p]

  s1_filter = Stage1Filter(stage1[0], stage1[1])
  s2_filter = Stage2Filter(stage2[0], stage2[1])
  return s1_filter, s2_filter



