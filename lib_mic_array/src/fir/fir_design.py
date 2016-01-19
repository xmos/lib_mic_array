#!/usr/bin/env python

import argparse
import numpy
import scipy
import matplotlib
import sys
import math
from scipy import signal
import matplotlib.pyplot as plt

################################################################################

def parseArguments(third_stage_configs):
    parser = argparse.ArgumentParser(description="Filter builder")

    parser.add_argument('--pdm-sample-rate', type=float, default=3072.0,
                        help='The sample rate (in kHz) of the PDM microphones',
                        metavar='kHz')
    parser.add_argument('--stopband-attenuation', type=int, default=100,
                        help='The desired attenuation to apply to the stop band at each stage')

    parser.add_argument('--first-stage-pass-bw', type=float, default=16.0,
                        help='The pass bandwidth (in kHz) of the first stage filter.'
                             ' Starts at 0Hz and ends at this frequency',
                        metavar='kHz')
    parser.add_argument('--first-stage-stop-bw', type=float, default=80.0,
                        help='The stop bandwidth (in kHz) of the first stage filter.',
                        metavar='kHz')

    parser.add_argument('--second-stage-pass-bw', type=float, default=16.0,
                        help='The pass bandwidth (in kHz) of the second stage filter.'
                             ' Starts at 0Hz and ends at this frequency',
                        metavar='kHz')
    parser.add_argument('--second-stage-stop-bw', type=float, default=14.0,
                        help='The stop bandwidth (in kHz) of the second stage filter.',
                        metavar='kHz')

    parser.add_argument('--third-stage-num-taps', type=int, default=32, choices=range(1,33),
                        help='The number of FIR taps per stage (decimation factor).'
                             ' The fewer there are the lower the group delay.')

    parser.add_argument('--add-third-stage', nargs=4,
                        help='Add a third stage filter e.g. 12 0.4 0.55 my_filt',
                        metavar=('DIVIDER', 'NORM_PASS', 'NORM_STOP', 'NAME'))

    args = parser.parse_args()

    to_add = args.add_third_stage
    if to_add:
        try:
            divider = int(to_add[0])
            norm_pass = float(to_add[1])
            norm_stop = float(to_add[2])
            name = to_add[3]
            third_stage_configs.append(
                [divider, norm_pass, norm_stop, name])
        except:
            print("ERROR: Invalid arguments for third stage")
            sys.exit(1)

    return args

################################################################################

def measure_stopband_and_ripple(bands, H):
    dbs = 20 * numpy.log10(abs(H))
    worst_stop_band_atten = -1000000
    pass_band_max = -1000000
    pass_band_min = 1000000
    atten = -1000000
    for f in range(0, dbs.size):
      freq = f * (0.5/ dbs.size)
      is_in_stop_band = 0
      for b in range(2, len(bands), 2):
        if freq > bands[b] and freq < bands[b+1]:
          is_in_stop_band = 1
        if is_in_stop_band:
          atten = dbs[f] - dbs[0]
      if worst_stop_band_atten < atten:
        worst_stop_band_atten = atten
      if freq > bands[0] and freq < bands[1]:
         p = dbs[f] - dbs[0]
         if pass_band_max < p:
           pass_band_max = p
         if pass_band_min > p:
           pass_band_min = p
    passband_ripple = pass_band_max - pass_band_min

    return [worst_stop_band_atten, passband_ripple]

################################################################################

def plot_response(H, file_name):
  magnitude_response = 20 * numpy.log10(abs(H))
  input_freq = numpy.arange(0.0, 0.5, 0.5/len(magnitude_response))
  plt.clf()
  plt.plot(input_freq, magnitude_response)
  plt.ylabel('Magnitude Response')
  plt.xlabel('Normalised Input Freq')
  plt.savefig(file_name +'.eps', format='eps', dpi=1000)

################################################################################

def output_txt_file(h, num_taps_per_phase, file_name, filter_name):
  f = open (file_name + ".fir_coefs", 'w')
  f.write(filter_name + "\n")
  f.write(str(num_taps_per_phase) + "\n")
  for i in h:
    f.write(str(i) + "\n")
  f.close()

################################################################################

def generate_stage(stage, num_taps, bands, a, divider=1, name=None):
  stage_string = "{} Stage{}".format(
    stage.capitalize(), " ({})".format(name) if name else "")
  print(stage_string)

  w = [1] * len(a)
  weight = 1.0
  stop_band_atten = 0
  while (-stop_band_atten) < args.stopband_attenuation:
    w[0] = weight

    try:
      h = signal.remez(divider*num_taps, bands, a, w)
    except ValueError:
      print("Failed to converge - unable to write filter: {}".format(stage_string))
      return

    (_, H) = signal.freqz(h)
    [stop_band_atten, passband_ripple] = measure_stopband_and_ripple(bands, H)
    weight = weight / 1.01

  print("Passband ripple: " + str(passband_ripple) + " dBs")
  print("Stopband attenuation: " + str(stop_band_atten) + " dBs")
  if name is None:
    output_txt_file(h, num_taps, stage + "_h", stage + "_stage")
  else:
    output_txt_file(h, num_taps, stage + "_stage_" + name + "_h", name)

  plot_response(H, stage + "_stage" + ("_{}".format(name) if name else ""))
  print("")

################################################################################

# Each entry generates a output
third_stage_configs = [
    [2,  0.35, 0.50, "div_2"],
    [4,  0.4, 0.55, "div_4"],
    [6,  0.4, 0.55, "div_6"],
    [8,  0.4, 0.55, "div_8"],
    [12, 0.4, 0.55, "div_12"]]

args = parseArguments(third_stage_configs)

# Do not change the following parameters
first_stage_num_taps = 48
second_stage_num_taps = 16

# First stage
bw = args.pdm_sample_rate
sbw = args.first_stage_stop_bw
nulls = bw/8.0
generate_stage(
  "first", first_stage_num_taps, [
    0,
    args.first_stage_pass_bw/bw,
    (nulls*1-sbw)/bw,
    (nulls*1+sbw)/bw,
    (nulls*2-sbw)/bw,
    (nulls*2+sbw)/bw,
    (nulls*3-sbw)/bw,
    (nulls*3+sbw)/bw,
    (nulls*4-sbw)/bw,
    0.5],
    [1, 0, 0, 0, 0]
  )

# Second stage
bw = args.pdm_sample_rate/8
nulls = bw/4.0
sbw = args.second_stage_stop_bw
generate_stage(
  "second", second_stage_num_taps, [
    0,
    args.second_stage_pass_bw/bw,
    (nulls*1-sbw)/bw,
    (nulls*1+sbw)/bw,
    (nulls*2-sbw)/bw,
    0.5],
    [1, 0, 0]
  )

# Third Stage
for (divider, normalised_pass, normalised_stop, name) in third_stage_configs:
  generate_stage(
    "third", args.third_stage_num_taps, [
      0,
      normalised_pass/divider,
      normalised_stop/divider,
      0.5],
      [1, 0],
      divider, name
    )
