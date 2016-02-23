from __future__ import division
import sys
from scipy.signal import blackmanharris
from numpy.fft import rfft, irfft
from numpy import argmax, sqrt, mean, absolute, arange, log10
import numpy as np

def rms_flat(a):
    return sqrt(mean(absolute(a)**2))

def find_range(f, x):
    """Find range between nearest local minima from peak at index x
    
    """

    for i in arange(x+1, len(f)):
        if f[i+1] >= f[i]:
            uppermin = i
            break
    for i in arange(x-1, 0, -1):
        if f[i] <= f[i-1]:
            lowermin = i + 1
            break
    return (lowermin, uppermin)

def THDN(signal, sample_rate, filename):

    signal = signal - mean(signal)  # this is so that the DC offset is not the peak in the case of PDM
    windowed = signal * blackmanharris(len(signal)) 

    total_rms = rms_flat(windowed)

    # Find the peak of the frequency spectrum (fundamental frequency), and filter 
    # the signal by throwing away values between the nearest local minima
    f = rfft(windowed)
    i = argmax(abs(f))

    #This will be exact if the frequency under test falls into the middle of an fft bin 
    print filename
    print 'Frequency: %f Hz' % (sample_rate * (i / len(windowed)))
    lowermin, uppermin = find_range(abs(f), i)
    f[lowermin: uppermin] = 0

    if len(f) > 24000:
       f[24000:len(f)-1] = 0

    noise = irfft(f)
    THDN = rms_flat(noise) / total_rms
    print "THD+N:     %.12f%% or %.12f dB" % (THDN * 100, 20 * log10(THDN))

def load(filename):
    signal = []
    sample_rate= 0.0
    frequency_under_test = 0.0
    sample_count = 0
    
    line_number = 0
    for line in open(filename,'r').readlines():
      if line_number == 0:
        sample_rate = float(line)
      elif line_number == 1:
        frequency_under_test = float(line)
      elif line_number == 2:
        sample_count = int(line)
      else:
        signal.append(float(line))
      line_number = line_number + 1
    return signal, sample_rate
    
files = sys.argv[1:]
if files:
    for filename in files:
       # try:
            signal, sample_rate = load(filename)
            THDN(signal, sample_rate, filename)
        #except:
       #    print 'Couldn\'t analyze "' + filename + '"'
       # print ''
else:
    sys.exit("You must provide at least one file to analyze")
