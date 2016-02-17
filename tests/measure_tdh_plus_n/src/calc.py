from __future__ import division
import sys
from scikits.audiolab import Sndfile
from scipy.signal import blackmanharris
from numpy.fft import rfft, irfft
from numpy import argmax, sqrt, mean, absolute, arange, log10
import numpy as np

def rms_flat(a):
    """Return the root mean square of all the elements of *a*, flattened out.
    
    """
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

def THDN(signal, sample_rate):
    """Measure the THD+N for a signal and print the results
    
    Prints the estimated fundamental frequency and the measured THD+N.  This is 
    calculated from the ratio of the entire signal before and after 
    notch-filtering.
    
    Currently this tries to find the "skirt" around the fundamental and notch 
    out the entire thing.  A fixed-width filter would probably be just as good, 
    if not better.
    
    """
    # Get rid of DC and window the signal
    signal -= mean(signal) # TODO: Do this in the frequency domain, and take any skirts with it?
    windowed = signal * blackmanharris(len(signal))  # TODO Kaiser?

    # Measure the total signal before filtering but after windowing
    total_rms = rms_flat(windowed)

    # Find the peak of the frequency spectrum (fundamental frequency), and filter 
    # the signal by throwing away values between the nearest local minima
    f = rfft(windowed)
    i = argmax(abs(f))
    print 'Frequency: %f Hz' % (sample_rate * (i / len(windowed))) # Not exact
    lowermin, uppermin = find_range(abs(f), i)
    f[lowermin: uppermin] = 0

    # Transform noise back into the signal domain and measure it
    # TODO: Could probably calculate the RMS directly in the frequency domain instead
    noise = irfft(f)
    THDN = rms_flat(noise) / total_rms
    print "THD+N:     %.4f%% or %.1f dB" % (THDN * 100, 20 * log10(THDN))

def load(filename):
    signal = []
    sample_rate= 0.0
    frequency_under_test = 0.0
    sample_count = 0
    
    line_number = 0
    for line in open('myfile','r').readlines():
      if line_number == 0:
        sample_rate = float(line)
      elif line_number == 1:
        frequency_under_test = float(line)
      elif line_number == 2:
        sample_count = float(line)
      else
        signal.append(line)
      line_number = line_number + 1
    print len(signal)
    print sample_count
    return signal, sample_rate
    
def analyze_channels(filename, function):
    signal, sample_rate = load(filename)
    print "Analyzing: " + str(sample_rate);
    function(signal, sample_rate)

files = sys.argv[1:]
if files:
    for filename in files:
        try:
            analyze_channels(filename, THDN)
        except:
            print 'Couldn\'t analyze "' + filename + '"'
        print ''
else:
    sys.exit("You must provide at least one file to analyze")