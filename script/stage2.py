# Copyright 2022 XMOS LIMITED.
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


  print("\n")
  print("{")
  print(", ".join( [hex(x) for x in stage2.Coef] ))
  print("}")


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("coef_pkl_file", type=str, help='Path to pkl file containing first and second stage coefficients.')

  args = parser.parse_args()
  main(args)