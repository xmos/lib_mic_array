from __future__ import division
import sys
import re
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
    print 'Frequency: %f Hz' % (sample_rate * (i / len(windowed)))
    lowermin, uppermin = find_range(abs(f), i)
    f[lowermin: uppermin] = 0

    if len(f) > 24000:
       f[24000:len(f)-1] = 0

    noise = irfft(f)
    THDN = rms_flat(noise) / total_rms
    print "THD+N:     %.12f%% or %.12f dB" % (THDN * 100, 20 * log10(THDN))

def load(filename):
    signals = []
    line_number = []
    for c in range(16):
        signal = []
        sample_rate= 0.0
        frequency_under_test = 0.0
        signals.append([signal, sample_rate, frequency_under_test])
        line_number.append(0)

    for line in open(filename,'r').readlines():
        if line.startswith("<Record Type=\""):
            n = re.findall('-*\d+', line)
            chan = int(n[0])
            value = int(n[4])

            if(line_number[chan] ==0):
                signals[chan][1] = float(value)
            elif line_number[chan] == 1:
                signals[chan][2]  = float(value)
            else:
                signals[chan][0].append(float(value))
            line_number[chan] += 1
    return signals
    
files = sys.argv[1:]
if files:
    for filename in files:
       # try:
            signals = load(filename)

            for s in signals:
                if len(s[0])>0:
                    #verify that all the outputs happened
                    print len(s[0])
                    THDN(s[0], s[1], filename)
        #except:
       #    print 'Couldn\'t analyze "' + filename + '"'
       # print ''
else:
    sys.exit("You must provide at least one file to analyze")
