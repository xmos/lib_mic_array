# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pickle as pkl
import numpy as np
from util import *
import random
import matplotlib.pyplot as plt

import filters


coef_file = "coef/32_6_257_65.pkl"

stage1, _ = filters.load(coef_file, truncate_s1=True)


# To make sure we did this right, let's create a random bipolar vector and see that we get the same result
if True:
  pdm_signal_bytes = stage1.TapCount // 8
  pdm_signal = np.array([random.randrange(0,255) for _ in range(pdm_signal_bytes)], dtype=np.uint8)
  pdm_binary = np.array(bits_array(pdm_signal), dtype=np.int)
  pdm_bipolar = (2*(pdm_binary - 0.5)).astype(np.int)

  res_flt = stage1.FilterFloat(pdm_bipolar)
  res_scaled = stage1.FilterInt16(pdm_bipolar)
  res_bip = stage1.FilterBipolar(pdm_bipolar)
  res_xcore = stage1.FilterXCore(pdm_binary)

  print(res_flt * stage1.ScaleInt16)
  print(res_scaled)
  print(res_bip)
  print(res_xcore)


# # convert the transpose of the bipolar coefficient matrix into a binary coefficient matrix, where
# # -1 maps to 1 and +1 maps to 0
# s1_coef_bin = bipolar_to_binary(s1_coef_bip.T)
# assert s1_coef_bin.shape == (16, 256)


# get the byte array representing the binary matrix
s1_coef_words = stage1.ToXCoreCoefArray()

print(f"Words: {len(s1_coef_words)}")

words = np.array(["0x%08X" % x for x in s1_coef_words], dtype=str).reshape((16,8))

print("{\n")

for r in range(words.shape[0]):
  print("  " + ", ".join(words[r,:]) + ", ")


print("\n}")

# # Output the result
# print("{\n\n" + ", ".join([hex(x) for x in s1_coef_words]) + "\n\n}")


