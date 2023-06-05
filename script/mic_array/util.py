# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import numpy as np
import struct

# Turn integer array into array of bits
def bits_array(x):
  return np.unpackbits(np.frombuffer(x.tobytes(), dtype=np.uint8), bitorder='little').astype(int)

# This is the dual vector whose inner product with a binary {-1, 1} vector
# produces the int16 being represented.
int16_dual = np.array([0x0001, 0x0002, 0x0004, 0x0008, 
                       0x0010, 0x0020, 0x0040, 0x0080,
                       0x0100, 0x0200, 0x0400, 0x0800, 
                       0x1000, 0x2000, 0x4000, 0x7FFF], dtype=np.int32)

# Find the bipolar matrix representation B[,] of an int16 vector x[] which satisfies
#   (np.matmul(B[:,:], dual_vector[:]) / 2) == x[:]
# If len(x) == N, then the returned matrix B[,] will have shape (N, 16).
# The first column, B[k,0], must correspond to the LEAST significant bit of the 
# transformed coefficient x[k]
def int16_vect_to_bipolar_matrix(x, dual_vector):
  x = x.astype(np.int64)
  y = 2*x[:,0] if (len(x.shape)==2) else 2*x
  res = np.zeros((len(y), 16), dtype=np.int32)
  for k in range(15,-1,-1):
    p = (y >= 0) * 2 - 1
    res[:,k] = p
    y = y - p * dual_vector[k] 
  return res


def pdm_signal_from_file(fname: str, /, binary=False):
  
  with open(fname, 'rb') as file:
    data = file.read()
    N_words = len(data) // 4
    signal_words = np.array( struct.unpack("I"*N_words, data), dtype=np.uint32 )

  # signal_words is the sequence of 32-bit words that are delivered by the port. Later words were received later.
  # The MSb of each word is the latest sample. Taken together, these mean that bit index k or word j is the 
  # (32*j+k)'th PDM sample

  N_pdm = len(signal_words) * 32
  signal_pdm = np.unpackbits(np.frombuffer(signal_words.tobytes(), dtype=np.uint8), bitorder='little')

  if not binary:
    signal_pdm = (1 - 2*signal_pdm.astype(np.int32)).astype(np.int32)
  
  return signal_pdm