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

max_intput_val = 1<<30
taps_per_phase = 48

#max input to the FIR from the previous atage
m = float(0x7fffffff)/float(0x40000000)

print('// Copyright (c) 2015, XMOS Ltd, All rights reserved')
print('#include \"mic_array_defines.h\"')
N = (1*taps_per_phase) # Filter order
if N%2==0:
   h = signal.firwin(N-1, 0.9)
else:
   h = signal.firwin(N, 0.9)

abs_sum = 0;
for s in h:
   abs_sum = abs_sum + abs(s)  


print('const int fir_1_coefs[1][COEFS_PER_PHASE] = {')
print('{')
counter = 0
for i in range(0, N, 1):
 if(i < len(h)):
   print('%10d,' % (h[i]*0x7fffffff/abs_sum*m)),
 else:
   print('%10d,' % 0),
 counter = counter + 1
 if (counter == 8):
   print('')
   counter = 0
print('')
print('},')
print('};')


for decimation_factor in range(2, 8+1, 1):
   N = (decimation_factor*taps_per_phase) # Filter order
   if N%2==0:
     h = signal.firwin(N-1, 1.0/decimation_factor)
   else:
     h = signal.firwin(N, 1.0/decimation_factor)
   
   abs_sum = 0;
   for s in h:
      abs_sum = abs_sum + abs(s)  

   print('const int fir_%d_coefs[%d][COEFS_PER_PHASE] = {' % (decimation_factor, decimation_factor))

   for s in range(0, decimation_factor, 1):
      print('{')
      counter = 0
      for i in range(0, N, decimation_factor):
         if(s+i < len(h)):
           print('%10d,' % (h[s+i]*0x7fffffff/abs_sum*m)),
         else:
           print('%10d,' % 0),
         counter = counter + 1
         if (counter == 8):
           print('')
           counter = 0
      print('')
      print('},')
   print('};')


print('const int * fir_coefs[9] = {')
print('        0,')
print('        fir_1_coefs[0],')
print('        fir_2_coefs[0],')
print('        fir_3_coefs[0],')
print('        fir_4_coefs[0],')
print('        fir_5_coefs[0],')
print('        fir_6_coefs[0],')
print('        fir_7_coefs[0],')
print('        fir_8_coefs[0]')
print('};')



