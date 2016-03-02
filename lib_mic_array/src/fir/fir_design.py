#!/usr/bin/env python

import argparse
import numpy
import scipy
import ctypes
import matplotlib
import sys
import math
import datetime
from scipy import signal
import matplotlib.pyplot as plt

#This controls the resolution of the FIR compansation
response_point_count = 100

###############################################################################

def parseArguments(third_stage_configs):
    parser = argparse.ArgumentParser(description="Filter builder")

    parser.add_argument('--pdm-sample-rate', type=float, default=3072.0,
                        help='The sample rate (in kHz) of the PDM microphones',
                        metavar='kHz')
    parser.add_argument('--stopband-attenuation', type=int, default=80,
      help='The desired attenuation to apply to the stop band at each stage')

    parser.add_argument('--first-stage-pass-bw', type=float, default=16.0,
      help='The pass bandwidth (in kHz) of the first stage filter.'
                             ' Starts at 0Hz and ends at this frequency',
                        metavar='kHz')
    parser.add_argument('--first-stage-stop-bw', type=float, default=100.0,
      help='The stop bandwidth (in kHz) of the first stage filter.',
                        metavar='kHz')

    parser.add_argument('--second-stage-pass-bw', type=float, default=16.0,
      help='The pass bandwidth (in kHz) of the second stage filter.'
                             ' Starts at 0Hz and ends at this frequency',
                        metavar='kHz')
    parser.add_argument('--second-stage-stop-bw', type=float, default=16.0,
      help='The stop bandwidth (in kHz) of the second stage filter.',
                        metavar='kHz')

    parser.add_argument('--third-stage-num-taps', type=int, default=32,
      choices=range(1,33), help='The number of FIR taps per stage '
      '(decimation factor). The fewer there are the lower the group delay.')

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

###############################################################################

def measure_stopband_and_ripple(bands, a, H):

    passband_max = float('-inf');
    passband_min = float('inf');
    stopband_max = float('-inf');

    #The bands are evenly spaced throughout 0 to 0.5 of the bandwidth
    for h in range(0, H.size):
      freq = 0.5*h/(H.size)
      mag = 20.0 * numpy.log10(abs(H[h]))
      for r in range(0, len(bands), 2):
        if freq > bands[r] and freq < bands[r+1]:
          if a[r/2] == 0:
            stopband_max = max(stopband_max, mag)
          else:
            passband_max = max(passband_max, mag)
            passband_min = min(passband_min, mag)

    return [stopband_max, passband_max, passband_min]

###############################################################################

def plot_response(H, file_name):
  magnitude_response = 20 * numpy.log10(abs(H))
  input_freq = numpy.arange(0.0, 0.5, 0.5/len(magnitude_response))
  plt.clf()
  plt.plot(input_freq, magnitude_response)
  plt.ylabel('Magnitude Response')
  plt.xlabel('Normalised Input Freq')
  plt.savefig(file_name +'.pdf', format='pdf', dpi=1000)

###############################################################################


def generate_stage(num_taps, bands, a, divider=1, num_frequency_points=2048):
  
  w = [1] * len(a)

  weight_min = 0.0
  weight_max = 32.0

  running = True

  epsilon = 0.00000001

  stopband_attenuation = 75.0

  while running:
    test_weight = (weight_min + weight_max)/2.0
    for i in range(0, len(a)-1):
      if a[i] != 0:
        w[i] = test_weight
    try:
      h = signal.remez(num_taps, bands, a, w)
      
      (_, H) = signal.freqz(h, worN=2048)

      [stop_band_atten, _, _ ] = measure_stopband_and_ripple(bands, a, H)

      if (-stop_band_atten) >  stopband_attenuation:
        weight_min = test_weight
      else:
        weight_max = test_weight

      if abs(weight_min - weight_max) < epsilon:
        running=False
    except ValueError:
      if abs(test_weight - weight_max) < epsilon:
        print "Failed to converge - unable to create filter"
        return
      else:
        weight_min = test_weight

  (_, H) = signal.freqz(h, worN=num_frequency_points)
  
  return H, h

###############################################################################

def generate_first_stage(header, body, points):

  first_stage_num_taps = 48

 # points = int(bw/(2*khz_per_point))

  pbw = args.first_stage_pass_bw/args.pdm_sample_rate
  sbw = args.first_stage_stop_bw/args.pdm_sample_rate
  nulls = 1.0/8.0
  a = [1, 0, 0, 0, 0]

  bands = [ 0,           pbw,
            nulls*1-sbw, nulls*1+sbw,
            nulls*2-sbw, nulls*2+sbw,
            nulls*3-sbw, nulls*3+sbw,
            nulls*4-sbw, 0.5]

  first_stage_response, coefs =  generate_stage( 
    first_stage_num_taps, bands, a)

  #ensure the there is never any overflow 
  coefs /= sum(abs(coefs))

  total_abs_sum = 0
  for t in range(0, len(coefs)/(8*2)):
    header.write("extern const int g_first_stage_fir_"+str(t)+"[256];\n")
    body.write("const int g_first_stage_fir_"+str(t)+"[256] = {\n\t")
    max_for_block = 0
    for x in range(0, 256):
      d=0.0
      for b in range(0, 8):
        if(((x>>(7-b))&1) == 1) :
          d = d + coefs[t*8 + b]
        else:
          d = d - coefs[t*8 + b]
      d_int = int(d*2147483647.0)
      max_for_block = max(max_for_block, d_int)
      body.write("0x{:08x}, ".format(ctypes.c_uint(d_int).value))
      if (x&7)==7:
        body.write("\n\t")
    body.write("};\n\n")
    total_abs_sum = total_abs_sum + max_for_block*2

  #print str(total_abs_sum) + "(" + str(abs(total_abs_sum - 2147483647.0)) + ")"
  if abs(total_abs_sum - 2147483647.0) > 6:
    print "Warning: error in first stage too large"

  body.write("const int fir1_debug[" + str(first_stage_num_taps) + "] = {\n\n")
  header.write("extern const int fir1_debug[" + str(first_stage_num_taps) + "];\n")
  for i in range(0, len(coefs)):
    body.write("{:10d}, ".format(int(2147483647.0*coefs[i])))
    if((i&7)==7):
      body.write("\n")
  body.write("};\n")

  (_, H) = signal.freqz(coefs, worN=points)
  plot_response(H, 'first_stage')
  [stop, passband_min, passband_max] = measure_stopband_and_ripple(bands, a, H)
  max_passband_output = int(2147483647.0 * 10.0 ** (passband_max/20.0) + 1)
  header.write("#define FIRST_STAGE_MAX_PASSBAND_OUTPUT (" + str(max_passband_output) +")\n")
  header.write("\n")

  return H

###############################################################################

def generate_second_stage(header, body, points):

  second_stage_num_taps = 16

  pbw = args.second_stage_pass_bw/(args.pdm_sample_rate/8.0)
  sbw = args.second_stage_stop_bw/(args.pdm_sample_rate/8.0)
  nulls = 1.0/4.0
  a = [1, 0, 0]

  bands = [ 0,           pbw,
            nulls*1-sbw, nulls*1+sbw,
            nulls*2-sbw, 0.5]

  second_stage_response, coefs =  generate_stage( 
    second_stage_num_taps, bands, a)

  #ensure the there is never any overflow 
  coefs /= sum(abs(coefs))

  header.write("extern const int g_second_stage_fir[8];\n")
  body.write("const int g_second_stage_fir[8] = {\n")

  total_abs_sum = 0
  for i in range(0, len(coefs)/2):
    if coefs[i] > 0.5:
      print "Single coefficient too big in second stage FIR"
    d_int = int(coefs[i]*2147483647.0*2.0);
    total_abs_sum += abs(d_int*2)
    body.write("\t0x{:08x},\n".format(ctypes.c_uint(d_int).value))
  body.write("};\n\n")

  #print str(total_abs_sum) + "(" + str(abs(total_abs_sum - 2147483647*2)) + ")"
  if abs(total_abs_sum - 2147483647*2) > 10:
    print "Warning: error in second stage too large"

  body.write("const int fir2_debug[" + str(second_stage_num_taps) + "] = {\n")
  header.write("extern const int fir2_debug[" + str(second_stage_num_taps) + "];\n\n")
  for i in range(0, len(coefs)):
    body.write("{:10d}, ".format(int(2147483647.0*coefs[i])))
    if((i&7)==7):
      body.write("\n")
  body.write("};\n\n")

  (_, H) = signal.freqz(coefs, worN=points) # this is where the ripple is derived from 
  plot_response(H, 'second_stage')

  [stop, passband_min, passband_max] = measure_stopband_and_ripple(bands, a, H)

  return H

###############################################################################

def generate_third_stage(header, body, third_stage_configs, combined_response, points):

  max_coefs_per_phase = 32

  for config in third_stage_configs:
    divider  = config[0]
    passband = config[1]
    stopband = config[2]
    name     = config[3]
    coefs_per_phase = config[4]

    pbw = passband/divider
    sbw = stopband/divider

    a = [1, 0]

    bands = [0, pbw, sbw, 0.5]

    third_stage_response, coefs =  generate_stage( 
      coefs_per_phase*divider, bands, a)

    #ensure the there is never any overflow 
    coefs /= sum(abs(coefs))

    body.write("const int g_third_stage_" +name+ "_fir["+str(divider*(2*max_coefs_per_phase - 1))+ "] = {\n");
    header.write("extern const int g_third_stage_" +name+ "_fir["+str(divider*(2*max_coefs_per_phase - 1))+ "];\n");
    
    total_abs_sum = 0
    for phase in reversed(range(divider)):
      body.write("//Phase " + str(phase)+"\n\t")
      for i in range(coefs_per_phase):
        index = coefs_per_phase*divider - divider - (i*divider - phase);
        if coefs[i] > 0.5:
          print "Single coefficient too big in third stage FIR"
        d_int = int(coefs[index]*2147483647.0*2.0);
        total_abs_sum += abs(d_int)
        body.write("0x{:08x}, ".format(ctypes.c_uint(d_int).value))
        if (i%8)==7: 
          body.write("\n\t");
      for i in range(coefs_per_phase, max_coefs_per_phase):
        body.write("0x{:08x}, ".format(ctypes.c_uint(0).value))
        if (i%8)==7: 
          body.write("\n\t");

      for i in range(coefs_per_phase-1):
        index = coefs_per_phase*divider - divider - (i*divider - phase);
        d_int = int(coefs[index]*2147483647.0*2.0);
        body.write("0x{:08x}, ".format(ctypes.c_uint(d_int).value))
        if (i%8)==7: 
          body.write("\n\t");
      for i in range(coefs_per_phase-1, max_coefs_per_phase-1):
        body.write("0x{:08x}, ".format(ctypes.c_uint(0).value))
        if (i%8)==7: 
          body.write("\n\t");

      body.write("\n");

    body.write("};\n");

    #print str(total_abs_sum) + "(" + str(abs(total_abs_sum - 2147483647.0*2.0)) + ")"
    if abs(total_abs_sum - 2147483647.0*2.0) > 32*divider:
      print "Warning: error in third stage too large"

    body.write("const int fir3_"+ name+"_debug[" + str(max_coefs_per_phase*divider)+ "] = {\n\t");
    header.write("extern const int fir3_"+ name+"_debug[" + str(max_coefs_per_phase*divider) + "];\n");

    for i in range(coefs_per_phase*divider):
      body.write("{:10d}, ".format(int(2147483647.0*coefs[i])))
      if (i%8)==7: 
        body.write("\n\t");
    
    for i in range(coefs_per_phase*divider, max_coefs_per_phase*divider):
      body.write("{:10d}, ".format(int(0)))
      if (i%8)==7: 
        body.write("\n\t");
    
    body.write("};\n");

    (_, H) = signal.freqz(coefs, worN=points) 

    plot_response(H, 'third_stage_' + str(name))

    passband_max = float('-inf');
    passband_min = float('inf');

    magnitude_response = []
    input_freq = []

    for i in range(points):
      mag = combined_response[i] * abs(H[i])
      freq = 0.5*i/points
      if freq < 0.5/divider:
        magnitude_response.append(mag)
        input_freq.append(freq*divider)
      if freq < passband/divider:
        passband_max = max(passband_max, mag)
        passband_min = min(passband_min, mag)

    magnitude_response /= passband_max
    magnitude_response = 20*numpy.log10(magnitude_response)
    plt.clf()
    plt.plot(input_freq, magnitude_response)
    plt.ylabel('Magnitude Response')
    plt.xlabel('Normalised Output Freq')
    plt.savefig("output_" + name +'.pdf', format='pdf', dpi=1000)

    print "Filter name: " + name
    print "Final stage divider: " + str(divider)
    print "(3.072MHz) Passband:" + str(48000*2*passband/divider) + "Hz Stopband:"+ str(48000*2*stopband/divider) + "Hz"
    print "(2.822MHz) Passband:" + str(44100*2*passband/divider) + "Hz Stopband:"+ str(44100*2*stopband/divider) + "Hz"
    
    if 1.0/passband_max > 8.0:
      print "Error: Compensation factor is too large"

    #The compensation factor should be in Q(5.27) format
    comp_factor = ((1<<27) - 1)/passband_max

    header.write("#define FIR_COMPENSATOR_" + name.upper() + " (" + str(int(comp_factor)) +")\n")

    header.write("\n")
    print "Passband ripple = " + str(20.0*numpy.log10(passband_min/passband_max)) +" dB\n"

  return

###############################################################################

if __name__ == "__main__":
  # Each entry generates a output
  third_stage_configs = [
      [2,  0.38, 0.50, "div_2", 32],
      [4,  0.40, 0.50, "div_4", 32],
      [6,  0.40, 0.50, "div_6", 32],
      [8,  0.40, 0.50, "div_8", 32],
      [12, 0.40, 0.50, "div_12", 32]
  ]
  args = parseArguments(third_stage_configs)

  header = open ("fir_coefs.h", 'w')
  body   = open ("fir_coefs.xc", 'w')

  year = datetime.datetime.now().year
  header.write("// Copyright (c) " +str(year) +", XMOS Ltd, All rights reserved\n")
  body.write("// Copyright (c) " +str(year) +", XMOS Ltd, All rights reserved\n")

  points = 8192*8
  combined_response = []

  first_stage_response = generate_first_stage(header, body, points)
  #Save the response between 0 and 48kHz
  for r in range(0, points/(8*4)+1):
    combined_response.append(abs(first_stage_response[r]))

  second_stage_response = generate_second_stage(header, body, points/8)
  for r in range(0, points/(8*4)):
    combined_response[r] = combined_response[r] * abs(second_stage_response[r])

  generate_third_stage(header, body, third_stage_configs, combined_response, points/(8*4))

  header.write("#define THIRD_STAGE_COEFS_PER_STAGE (32)\n")
  