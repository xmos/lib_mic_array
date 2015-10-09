import numpy
from numpy import log10, abs, pi
import scipy
from scipy import signal
import matplotlib
import matplotlib.pyplot
import matplotlib as mpl
import sys, getopt
import math
# ~~[Filter Design with Parks-McClellan Remez]~~

max_intput_val = 1<<31
taps_per_phase = 48

for decimation_factor in range(2, 8+1, 1):
   N = (decimation_factor*taps_per_phase) # Filter order

   sf = (0xffffffffffffffff/(N*max_intput_val))
   if N%2==0:
     h = signal.firwin(N-1, 1.0/decimation_factor)
   else:
     h = signal.firwin(N, 1.0/decimation_factor)

   print('const int fir_%d_coefs[%d][COEFS_PER_PHASE] = {' % (decimation_factor, decimation_factor))

   for s in range(0, decimation_factor, 1):
      print('{')
      counter = 0
      for i in range(0, N, decimation_factor):
         if(s+i < len(h)):
           print('%10d,' % (h[s+i]*sf)),
         else:
           print('%10d,' % 0),
         counter = counter + 1
         if (counter == 8):
           print('')
           counter = 0
      print('')
      print('},')
   print('};')