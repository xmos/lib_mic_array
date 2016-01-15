import numpy
import scipy
import matplotlib
import sys, getopt
import math
from scipy import signal
import matplotlib.pyplot as plt

PDM_sample_rate = 3072.0;
stopband_attenuation = 100;

first_stage_pass_bandwidth = 16.0;
first_stage_stop_bandwidth = 80.0;

second_stage_pass_bandwidth = 16.0;
second_stage_stop_bandwidth = 14.0;

third_stage_num_taps_per_phase = 32

#Each entry generates a output 
third_stage_configs = [
    [2,  0.35, 0.50, "div_2"],
    [4,  0.4, 0.55, "div_4"], 
    [6,  0.4, 0.55, "div_6"], 
    [8,  0.4, 0.55, "div_8"], 
    [12, 0.4, 0.55, "div_12"]]

#Do not change parameters below here
first_stage_num_taps = 48
second_stage_num_taps = 16

if third_stage_num_taps_per_phase > 32:
  print("There cannot be more then 32 taps per third phase: third_stage_num_taps_per_phase = 32")
  third_stage_num_taps_per_phase = 32

def measure_stopband_and_ripple(bands, H):
    dbs = 20*numpy.log10(abs(H));
    worst_stop_band_atten = -1000000;
    pass_band_max = -1000000;
    pass_band_min = 1000000;
    atten = -1000000
    for f in range(0, dbs.size):
      freq = f * (0.5/ dbs.size);
      is_in_stop_band = 0;
      for b in range(2, len(bands), 2):
        if freq > bands[b] and freq < bands[b+1]:
          is_in_stop_band = 1;
        if is_in_stop_band:
          atten = dbs[f] - dbs[0];
      if worst_stop_band_atten < atten:
        worst_stop_band_atten = atten
      if freq > bands[0] and freq < bands[1]:
         p = dbs[f] - dbs[0];
         if pass_band_max < p:
           pass_band_max = p
         if pass_band_min > p:
           pass_band_min = p
    passband_ripple = pass_band_max - pass_band_min;

    return [worst_stop_band_atten, passband_ripple]

def plot_response(H, file_name):
  magnitude_response = 20*numpy.log10(abs(H));
  input_freq = numpy.arange(0.0, 0.5, 0.5/len(magnitude_response));
  plt.clf();
  plt.plot(input_freq, magnitude_response);
  plt.ylabel('Magnitude Response')
  plt.xlabel('Normalised Input Freq')
  plt.savefig(file_name +'.eps', format='eps', dpi=1000)
  return 

def output_txt_file(h, num_taps_per_phase, file_name, filter_name):
  f = open (file_name + ".fir_coefs", 'w');
  f.write(filter_name + "\n");
  f.write(str(num_taps_per_phase) + "\n");
  for i in h:
    f.write(str(i) + "\n");
  f.close();
  return 

bw = PDM_sample_rate;
nulls = (bw)/8.0;
sbw = first_stage_stop_bandwidth;
first_stage_bands = [0, 
	first_stage_pass_bandwidth/bw, 
	(nulls*1-sbw)/bw, 
	(nulls*1+sbw)/bw, 
	(nulls*2-sbw)/bw, 
	(nulls*2+sbw)/bw, 
	(nulls*3-sbw)/bw, 
	(nulls*3+sbw)/bw, 
	(nulls*4-sbw)/bw, 
	0.5];
a = [1, 0, 0, 0, 0];
weight = 1.0
stop_band_atten = 0;
while (-stop_band_atten) < stopband_attenuation:
  w = [weight, 1, 1, 1, 1];
  first_h = signal.remez(first_stage_num_taps, first_stage_bands, a, w)
  (w,H) = signal.freqz(first_h)
  [stop_band_atten, passband_ripple] = measure_stopband_and_ripple(first_stage_bands, H);
  weight = weight / 1.01;

print("First Stage")
print("Passband ripple:" + str(passband_ripple) + " dBs")
print("Stopband attenuation:" + str(stop_band_atten) + " dBs")
output_txt_file(first_h, first_stage_num_taps, "first_h", "first_stage");
plot_response(H, "first_stage");
print("")

#Second stage
bw = PDM_sample_rate/8;
nulls = (bw)/4.0;
sbw = second_stage_stop_bandwidth;
second_stage_bands = [0, 
	second_stage_pass_bandwidth/bw, 
	(nulls*1-sbw)/bw, 
	(nulls*1+sbw)/bw, 
	(nulls*2-sbw)/bw, 
	0.5];
a = [1, 0, 0];
weight = 1.0
stop_band_atten = 0;
while (-stop_band_atten) < stopband_attenuation:
  w = [weight, 1, 1];
  second_h = signal.remez(second_stage_num_taps, second_stage_bands, a, w)
  (w,H) = signal.freqz(second_h)
  [stop_band_atten, passband_ripple] = measure_stopband_and_ripple(second_stage_bands, H);
  weight = weight / 1.01;

print("Second Stage")
print("Passband ripple:" + str(passband_ripple) + " dBs")
print("Stopband attenuation:" + str(stop_band_atten) + " dBs")
output_txt_file(second_h, second_stage_num_taps, "second_h", "second_stage");
plot_response(H, "second_stage");
print("")

#Third Stage
for config in third_stage_configs:

	divider = config[0]
	normalised_pass = config[1]
	normalised_stop = config[2]
	name = config[3]
	weight = 1.0;
	stop_band_atten = 0;

	#TODO use a binary search here to massivly improve preformance
	while (-stop_band_atten) < stopband_attenuation:
	  third_stage_bands = [0, normalised_pass/divider, normalised_stop/divider, 0.5]
	  third_h = signal.remez(divider*third_stage_num_taps_per_phase, third_stage_bands, [1, 0], [weight, 1])
	  (w,H) = signal.freqz(third_h)
	  [stop_band_atten, passband_ripple] =  measure_stopband_and_ripple(third_stage_bands, H);
	  weight = weight / 1.01

	print("Third Stage ("+ name + ")")
	print("Passband ripple:" + str(passband_ripple) + " dBs")
	print("Stopband attenuation:" + str(stop_band_atten) + " dBs")
	print("")
	output_txt_file(third_h, third_stage_num_taps_per_phase, "third_stage_"+ name + "_h", name);
	plot_response(H, "third_stage_div_"+ str(divider));






