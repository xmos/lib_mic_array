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

###############################################################################

def parseArguments(third_stage_configs):
    parser = argparse.ArgumentParser(description="Filter builder")

    #this must be set for all other bandwidths to be relative to
    parser.add_argument('--pdm-sample-rate', type=float, default=3072.0,
                        help='The sample rate (in kHz) of the PDM microphones',
                        metavar='kHz')

    parser.add_argument('--use-low-ripple-first-stage', type=bool, default=False,
      help='Use the lowest ripple possible for the given output passband.')

    parser.add_argument('--first-stage-num-taps', type=int, default=48,
      help='The number of FIR taps in the first stage of decimation.')
    parser.add_argument('--first-stage-pass-bw', type=float, default = 20.0,
      help='The pass bandwidth (in kHz) of the first stage filter.'
          ' Starts at 0Hz and ends at this frequency', metavar='kHz')
    parser.add_argument('--first-stage-stop-bw', type=float, default = 24.0,
      help='The stop bandwidth (in kHz) of the first stage filter.',
      metavar='kHz')
    parser.add_argument('--first-stage-stop-atten', type=float, default = -120.0,
      help='The stop band attenuation(in dB) of the first stage filter(Normally negative).', metavar='dB')

    parser.add_argument('--second-stage-pass-bw', type=float, default=16,
       help='The number of FIR taps per stage '
          ' Starts at 0Hz and ends at this frequency', metavar='kHz')
    parser.add_argument('--second-stage-stop-bw', type=float, default=16,
       help='The number of FIR taps per stage '
          ' Starts at 0Hz and ends at this frequency', metavar='kHz')
    parser.add_argument('--second-stage-stop-atten', type=float, default = -70.0,
      help='The stop band attenuation(in dB) of the second stage filter(Normally negative).', metavar='dB')

    parser.add_argument('--third-stage-num-taps', type=int, default=32,
       help='The number of FIR taps per stage '
      '(decimation factor). The fewer there are the lower the group delay.')

    parser.add_argument('--third-stage-stop-atten', type=float, default = -70.0,
      help='The stop band attenuation(in dB) of the third stage filter(Normally negative).', metavar='dB')

    parser.add_argument('--add-third-stage', nargs=5,
      help='Add a custom third stage filter; e.g. 6 6.2 8.1 custom_16k_filt 32',
                        metavar=('DIVIDER', 'PASS_BANDWIDTH', 'STOP_BAND_START', 'NAME', 'NUM_TAPS'))

    args = parser.parse_args()

    to_add = args.add_third_stage
    if to_add:
    	pdm_rate = float(args.pdm_sample_rate)
    	print "****** Input rate for custom filter: " + str(args.pdm_sample_rate) + "kHz. ********"
        try:
            divider = int(to_add[0])
            passbw = float(to_add[1])
            stopbw = float(to_add[2])
            name = str(to_add[3])
            num_taps = int(to_add[4])
            norm_pass = passbw / (pdm_rate/8/4 / divider)
            norm_stop = stopbw / (pdm_rate/8/4 / divider)
            third_stage_configs.append(
                [divider, norm_pass, norm_stop, name, num_taps, True])
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


def generate_stage(num_taps, bands, a, weights, divider=1, num_frequency_points=2048, stopband_attenuation = -65.0):
  
  w = [1] * len(a)

  weight_min = 0.0
  weight_max = 1024.0

  running = True

  epsilon = 0.0000000001

  while running:
    test_weight = (weight_min + weight_max)/2.0
    for i in range(0, len(a)-1):
      if a[i] != 0:
        w[i] = test_weight*weights[i]
    try:
      h = signal.remez(num_taps, bands, a, w)
      
      (_, H) = signal.freqz(h, worN=2048)

      [stop_band_atten, passband_min, passband_max ] = measure_stopband_and_ripple(bands, a, H)

      if (-stop_band_atten) >  -stopband_attenuation:
        weight_min = test_weight
      else:
        weight_max = test_weight

      #print str(stop_band_atten) + ' ' + str(passband_max) + ' ' + str(passband_min) + ' ' +str(test_weight)
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

def generate_first_stage(header, body, points, pbw, sbw, first_stage_num_taps, first_stage_stop_atten):
  nulls = 1.0/8.0
  a = [1, 0]
  w = [1, 1]

  bands = [ 0, pbw, nulls-sbw, 0.5]

  return first_stage_output_coefficients(header, body, points, first_stage_num_taps, first_stage_stop_atten, nulls, a, w, bands)

def generate_first_stage_low_ripple(header, body, points, pbw, sbw, first_stage_num_taps, first_stage_stop_atten):

  nulls = 1.0/8.0
  a = [1, 0, 0, 0, 0]
  w = [1, 1, 1, 1, 1]
  bands = [ 0,           pbw,
            nulls*1-sbw, nulls*1+sbw,
            nulls*2-sbw, nulls*2+sbw,
            nulls*3-sbw, nulls*3+sbw,
            nulls*4-sbw, 0.5]

  return first_stage_output_coefficients(header, body, points, first_stage_num_taps, first_stage_stop_atten, nulls, a, w, bands)

def first_stage_output_coefficients(header, body, points, first_stage_num_taps, first_stage_stop_atten, nulls, a, w, bands):

  first_stage_response, coefs =  generate_stage( 
    first_stage_num_taps, bands, a, w, stopband_attenuation = first_stage_stop_atten)

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

def generate_second_stage(header, body, points,  pbw, sbw, second_stage_num_taps, stop_band_atten):

  nulls = 1.0/4.0
  a = [1, 0, 0]
  w = [1, 1, 1]

  bands = [ 0,           pbw,
            nulls*1-sbw, nulls*1+sbw,
            nulls*2-sbw, 0.5]

  second_stage_response, coefs =  generate_stage( 
    second_stage_num_taps, bands, a, w, stopband_attenuation = stop_band_atten)

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

def generate_third_stage(header, body, third_stage_configs, combined_response, points, input_sample_rate, stop_band_atten):

  max_coefs_per_phase = 32

  for config in third_stage_configs:
    divider  = config[0]
    passband = config[1]
    stopband = config[2]
    name     = config[3]
    coefs_per_phase = config[4]

    #if is_custom then use the PDM rate for making the graphs
    is_custom = config[5]

    pbw = passband/divider
    sbw = stopband/divider

    a = [1, 0]
    w = [1, 1]

    bands = [0, pbw, sbw, 0.5]

    third_stage_response, coefs =  generate_stage( 
      coefs_per_phase*divider, bands, a, w, stopband_attenuation = stop_band_atten)

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
        if is_custom:
          input_freq.append(freq*input_sample_rate)
        else:
          input_freq.append(freq*divider)
      if freq < passband/divider:
        passband_max = max(passband_max, mag)
        passband_min = min(passband_min, mag)

    magnitude_response /= passband_max
    magnitude_response = 20*numpy.log10(magnitude_response)
    plt.clf()
    plt.plot(input_freq, magnitude_response)
    plt.ylabel('Magnitude Response')
    if is_custom:
      plt.xlabel('Frequency (kHz)')
    else:
      plt.xlabel('Normalised Output Freq')
    plt.savefig("output_" + name +'.pdf', format='pdf', dpi=1000)

    print "Filter name: " + name
    print "Final stage divider: " + str(divider)
    print "Output sample rate: " + str(input_sample_rate/divider)+ "kHz"
    print "Pass bandwidth: " + str(input_sample_rate*passband/divider) + "kHz of " + str(input_sample_rate/(divider*2)) + "kHz total bandwidth."
    print "Pass bandwidth(normalised): " + str(passband*2) + " of Nyquist."
    print "Stop band start: " + str(input_sample_rate*stopband/divider) + "kHz of " + str(input_sample_rate/(divider*2)) + "kHz total bandwidth."
    print "Stop band start(normalised): " + str(stopband*2) + " of Nyquist."
    print "Stop band attenuation: " + str(stop_band_atten)+ "dB."

   # print "(3.072MHz) Passband:" + str(48000*2*passband/divider) + "Hz Stopband:"+ str(48000*2*stopband/divider) + "Hz"
   # print "(2.822MHz) Passband:" + str(44100*2*passband/divider) + "Hz Stopband:"+ str(44100*2*stopband/divider) + "Hz"
    
    if 1.0/passband_max > 8.0:
      print "Error: Compensation factor is too large"

    #The compensation factor should be in Q(5.27) format
    comp_factor = ((1<<27) - 1)/passband_max

    header.write("#define FIR_COMPENSATOR_" + name.upper() + " (" + str(int(comp_factor)) +")\n")

    header.write("\n")
    print "Passband ripple = " + str(abs(20.0*numpy.log10(passband_min/passband_max))) +" dB\n"
  return

###############################################################################

if __name__ == "__main__":
  # Each entry generates a output
  third_stage_configs = [
      #divider, normalised pb, normalised sb, name, taps per phase, is_custom
      [2,  0.38, 0.50, "div_2", 32, False],
      [4,  0.42, 0.52, "div_4", 32, False],
      [6,  0.42, 0.52, "div_6", 32, False],
      [8,  0.42, 0.52, "div_8", 32, False],
      [12, 0.42, 0.52, "div_12", 32, False]
  ]
  args = parseArguments(third_stage_configs)

  input_sample_rate = args.pdm_sample_rate
  input_band_width = input_sample_rate/2.0
  first_stage_pbw = args.first_stage_pass_bw/args.pdm_sample_rate
  first_stage_sbw = args.first_stage_stop_bw/args.pdm_sample_rate
  first_stage_num_taps = int(args.first_stage_num_taps)
  first_stage_stop_band_atten = args.first_stage_stop_atten
  first_stage_low_ripple = args.use_low_ripple_first_stage

#warnings
  if first_stage_stop_band_atten > 0:
  	print "Warning first stage stop band attenuation is positive."

  print "Filer Configuration:"
  print "Input(PDM) sample rate: " + str(input_sample_rate) + "kHz"
  print "First Stage"
  print "Num taps: " + str(first_stage_num_taps)
  print "Pass bandwidth: " + str(args.first_stage_pass_bw) + "kHz of " + str(input_band_width) + "kHz total bandwidth."
  print "Pass bandwidth(normalised): " + str(first_stage_pbw*2) + " of Nyquist."
  print "Stop band attenuation: " + str(first_stage_stop_band_atten)+ "dB."
  print "Stop bandwidth: " + str(args.first_stage_stop_bw) + "kHz"
  print "Lowest Ripple: " + str(first_stage_low_ripple) 


  header = open ("fir_coefs.h", 'w')
  body   = open ("fir_coefs.xc", 'w')

  year = datetime.datetime.now().year
  header.write("// Copyright (c) " +str(year) +", XMOS Ltd, All rights reserved\n")
  body.write("// Copyright (c) " +str(year) +", XMOS Ltd, All rights reserved\n")

  points = 8192*8
  combined_response = []

  if first_stage_low_ripple:
    first_stage_response = generate_first_stage_low_ripple(header, body, points, first_stage_pbw, first_stage_sbw, first_stage_num_taps, first_stage_stop_band_atten)
  else: 
    first_stage_response = generate_first_stage(header, body, points, first_stage_pbw, first_stage_sbw, first_stage_num_taps, first_stage_stop_band_atten)
  #Save the response between 0 and 48kHz
  for r in range(0, points/(8*4)+1):
    combined_response.append(abs(first_stage_response[r]))

  second_stage_num_taps = 16
  second_stage_pbw = args.second_stage_pass_bw/(input_sample_rate/8.0)
  second_stage_sbw = args.second_stage_stop_bw/(input_sample_rate/8.0)
  second_stage_stop_band_atten = args.second_stage_stop_atten

  print ""
#warnings
  if second_stage_stop_band_atten > 0:
  	print "Warning second stage stop band attenuation is positive."

  print "Second Stage"
  print "Num taps: " + str(second_stage_num_taps)
  print "Pass bandwidth: " + str(args.second_stage_pass_bw) + "kHz of " + str(input_sample_rate/8.0) + "kHz total bandwidth."
  print "Pass bandwidth(normalised): " + str(second_stage_pbw*2) + " of Nyquist."
  print "Stop band attenuation: " + str(second_stage_stop_band_atten)+ "dB."
  print "Stop bandwidth: " + str(args.second_stage_stop_bw) + "kHz"

  second_stage_response = generate_second_stage(header, body, points/8, second_stage_pbw, second_stage_sbw, second_stage_num_taps, second_stage_stop_band_atten)
  for r in range(0, points/(8*4)):
    combined_response[r] = combined_response[r] * abs(second_stage_response[r])

  third_stage_stop_band_atten = args.third_stage_stop_atten
  print ""
#warnings
  if third_stage_stop_band_atten > 0:
  	print "Warning third stage stop band attenuation is positive."

  print "Third Stage"
  generate_third_stage(header, body, third_stage_configs, combined_response, points/(8*4), input_sample_rate/8.0/4.0, third_stage_stop_band_atten)

  header.write("#define THIRD_STAGE_COEFS_PER_STAGE (32)\n")
  


