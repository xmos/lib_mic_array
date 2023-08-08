# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import numpy as np
from mic_array.util import *
import argparse

import mic_array.filters as filters


def main(args):

  stage1, _ = filters.load(args.coef_pkl_file)

  # get the byte array representing the binary matrix
  s1_coef_words = stage1.ToXCoreCoefArray()

  print(f"Filter word count: {len(s1_coef_words)}\n")

  words = np.array(["0x%08X" % x for x in s1_coef_words], dtype=str).reshape((16,8))

  print("{")

  for r in range(words.shape[0]):
    print("  " + ", ".join(words[r,:]) + ", ")

  print("}")



if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("coef_pkl_file", type=str, help='Path to pkl file containing first and second stage coefficients.')

  args = parser.parse_args()
  main(args)