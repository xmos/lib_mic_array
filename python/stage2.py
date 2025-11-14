# Copyright 2022-2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pickle as pkl
import numpy as np
from mic_array.util import *
import matplotlib.pyplot as plt
import argparse

import mic_array.filters as filters


def main(args):

  _, stage2 = filters.load(args.coef_pkl_file)

  # print(f"Scale: {stage2.ScaleInt32}")

  print(f"Right-shift: {stage2.Shr}")
  num_coefs = len(stage2.Coef)
  initial_count = (num_coefs//4) * 4
  print("\n")
  print("{")
  for i in range(0,initial_count,4): # print 4 coefs per row
    s = ", ".join( [hex(x) for x in stage2.Coef[i:i+4]] )
    print(s,end=',\n')

  if initial_count != num_coefs:
    print(", ".join( [hex(x) for x in stage2.Coef[initial_count:]] ))

  print("}")


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("coef_pkl_file", type=str, help='Path to pkl file containing first and second stage coefficients.')

  args = parser.parse_args()
  main(args)
