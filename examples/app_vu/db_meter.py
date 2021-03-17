# Copyright 2017-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

# -*- coding: utf-8 -*-
import numpy as np
import matplotlib.pyplot as plt
from scipy import signal

int32_max = np.int64(np.iinfo(np.int32).max)
int64_max = np.int64(np.iinfo(np.int64).max)

f1 = 20.598997 
f2 = 107.65265
f3 = 737.86223
f4 = 12194.217

p1 = np.poly1d([1, 2.*np.pi*f1])
p2 = np.poly1d([1, 2.*np.pi*f2])
p3 = np.poly1d([1, 2.*np.pi*f3])
p4 = np.poly1d([1, 2.*np.pi*f4])

def make_A_weighting(fs):

	p1_squared = np.polymul(p1, p1)
	p4_squared = np.polymul(p4, p4)

	den = p1
	den = np.polymul(den, p1)
	den = np.polymul(den, p4)
	den = np.polymul(den, p4)
	den = np.polymul(den, p2)  
	den = np.polymul(den, p3)

	num = np.poly1d([(2.*np.pi*f4)**2, 0, 0, 0, 0])

	B, A = signal.bilinear(num, den, fs)

	return B, A

def make_C_weighting(fs):

	den = p1
	den = np.polymul(den, p1)
	den = np.polymul(den, p4)
	den = np.polymul(den, p4)
	num = np.poly1d([(2.*np.pi*f4)**2, 0, 0])

	B, A = signal.bilinear(num, den, fs)
	return B, A

def output_filter(B, A, name, show_response = False, emit_test_ir = False, impulse_resp_length = 64):

	sos = signal.tf2sos(B, A)

	if show_response:
		B, A = signal.sos2tf(sos)
		w, h = signal.freqz(B, A, worN=2**12)
		plt.title('Digital filter frequency response')
		plt.semilogx(w*fs/(2.0*np.pi), 20 * np.log10(abs(h)), label = 'A_orig')
		plt.ylim(-50, 20)
		plt.ylabel('Amplitude [dB]', color='b')
		plt.xlabel('Frequency [rad/sample]')
		plt.grid()
		plt.show()

	filter_q = 31
	max_q_adjust = 0
	for bq in range(len(sos)):
		sos[bq] /= sos[bq][3]
		abs_sum = sum(abs(sos[bq])) - 1.0
		m = int(np.ceil(np.log2(abs_sum))) #TODO check this works for -ve abs_sums 
		max_q_adjust = max(max_q_adjust, m)

	max_q_adjust -= 1	#to take advantage of 64 bit maccs
	filter_q -= max_q_adjust

	#TODO check for -ve max_q_adjust

	sos_quantised = np.zeros(np.shape(sos))

	int_max = np.int64(int32_max) / 2**max_q_adjust
	print 'const int32_t filter_coeffs_' + name + '[] = {'
	for bq in range(len(sos)):
		print '\t',
		for i in range(3):
			v = np.int32(np.float64(int_max) * sos[bq][i])
			print str(v) + ', ' ,
			sos_quantised[bq][i] = np.float64(v) / np.float64(int_max)
		for i in range(4, 6):
			v = int(np.float64(int_max) * -sos[bq][i])
			sos_quantised[bq][i] = np.float64(-v) / np.float64(int_max)
			print str(v) + ', ' ,
		print
		sos_quantised[bq][3] = 1.0
	print '};'
	print 'const uint32_t num_sections_' + name + ' = ' + str(len(sos)) + ';'
	print 'const uint32_t q_format_' + name + ' = ' + str(filter_q) + ';'
	print 'int32_t filter_state_'+ name +'[' +str(len(sos)) + '*DSP_NUM_STATES_PER_BIQUAD] = {0};'
	d = np.zeros(impulse_resp_length)
	d[0] = 1

	B_q, A_q = signal.sos2tf(sos_quantised)
	filter_impulse_response =  signal.lfilter(B_q, A_q, d)

	if emit_test_ir:
		print 'const unsigned impulse_resp_length_' + name + ' = ' + str(impulse_resp_length)+';'
		print 'const int32_t expected_ir_' + name + '[' + str(impulse_resp_length) + '] = {'
		for i in range(impulse_resp_length):
			s = str(int(int32_max * filter_impulse_response[i])) + ', '
			if i%8 == 7:
				print s
			else:
				print s,
		print '};'

	return

if __name__ == "__main__":

	fs = 48000

	B_a, A_a = make_A_weighting(fs)
	B_a *= (10.**(2.0/20.))		#to normalise 1kHz to 0dB

	B_c, A_c = make_C_weighting(fs)
	B_c *= (10.**(0.06/20.))	#to normalise 1kHz to 0dB

	output_filter(B_a, A_a, 'A_weight')
	output_filter(B_c, A_c, 'C_weight')



