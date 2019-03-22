#!/usr/bin/python

import os
import numpy as np
import argparse
from scipy import signal
import scipy.io.wavfile
import operator

def decimate(x, q, n=None, ftype='iir', axis=-1, zero_phase=True):
    """
    Downsample the signal after applying an anti-aliasing filter.
    By default, an order 8 Chebyshev type I filter is used. A 30 point FIR
    filter with Hamming window is used if `ftype` is 'fir'.
    Parameters
    ----------
    x : array_like
        The signal to be downsampled, as an N-dimensional array.
    q : int
        The downsampling factor. When using IIR downsampling, it is recommended
        to call `decimate` multiple times for downsampling factors higher than
        13.
    n : int, optional
        The order of the filter (1 less than the length for 'fir'). Defaults to
        8 for 'iir' and 20 times the downsampling factor for 'fir'.
    ftype : str {'iir', 'fir'} or ``dlti`` instance, optional
        If 'iir' or 'fir', specifies the type of lowpass filter. If an instance
        of an `dlti` object, uses that object to filter before downsampling.
    axis : int, optional
        The axis along which to decimate.
    zero_phase : bool, optional
        Prevent phase shift by filtering with `filtfilt` instead of `lfilter`
        when using an IIR filter, and shifting the outputs back by the filter's
        group delay when using an FIR filter. The default value of ``True`` is
        recommended, since a phase shift is generally not desired.
        .. versionadded:: 0.18.0
    Returns
    -------
    y : ndarray
        The down-sampled signal.
    See Also
    --------
    resample : Resample up or down using the FFT method.
    resample_poly : Resample using polyphase filtering and an FIR filter.
    Notes
    -----
    The ``zero_phase`` keyword was added in 0.18.0.
    The possibility to use instances of ``dlti`` as ``ftype`` was added in
    0.18.0.
    """

    x = np.asarray(x)
    q = operator.index(q)

    if n is not None:
        n = operator.index(n)

    if ftype == 'fir':
        if n is None:
            half_len = 10 * q  # reasonable cutoff for our sinc-like function
            n = 2 * half_len
        b, a = firwin(n+1, 1. / q, window='hamming'), 1.
    elif ftype == 'iir':
        if n is None:
            n = 8
        system = signal.dlti(*signal.cheby1(n, 0.05, 0.95 / q))
        b, a = system.num, system.den
    elif isinstance(ftype, dlti):
        system = ftype._as_tf()  # Avoids copying if already in TF form
        b, a = system.num, system.den
    else:
        raise ValueError('invalid ftype')

    sl = [slice(None)] * x.ndim
    a = np.asarray(a)

    if a.size == 1:  # FIR case
        b = b / a
        if zero_phase:
            y = resample_poly(x, 1, q, axis=axis, window=b)
        else:
            # upfirdn is generally faster than lfilter by a factor equal to the
            # downsampling factor, since it only calculates the needed outputs
            n_out = x.shape[axis] // q + bool(x.shape[axis] % q)
            y = upfirdn(b, x, up=1, down=q, axis=axis)
            sl[axis] = slice(None, n_out, None)

    else:  # IIR case
        if zero_phase:
            y = signal.filtfilt(b, a, x, axis=axis, padlen = 1000, padtype='even')
        else:
            y = lfilter(b, a, x, axis=axis)
        sl[axis] = slice(None, None, q)

    return y[sl]

def delta_sigma_5th_order( data_in , output_length):
  "This outputs a 1-bit delta sigma modulated data set from an input data set of floating point samples"

  # Coefficients
  c = [0.791882, 0.304545, 0.069930, 0.009496, 0.000607];
  f = [0.000496, 0.001789];

  # Initialization
  s0 = s1 = s2 = s3 = s4 = 0.0; # Integrators
  data_out = np.ones(output_length)

  for i in range(1, min(len(data_in),output_length)):
      s4 = s4 + s3;
      s3 = s3 + s2 - f[1]*s4;
      s2 = s2 + s1;
      s1 = s1 + s0 - f[0]*s2;
      s0 = s0 + (data_in[i] - data_out[i-1]);
      s = c[0]*s0 + c[1]*s1 + c[2]*s2 + c[3]*s3 + c[4]*s4;

      if s < 0.0:
        data_out[i] = -1.0

  return data_out

def gcd(a, b): return gcd(b, a % b) if b else a

def up_down_ratio(input_rate, output_rate):
  i = int(input_rate)
  o = int(output_rate)
  d =  gcd(i, o)
  i = i / d
  o = o / d
  return o, i

def get_prime_factors(input):
    remainder = int(input)
    # TODO extend this
    primes = [2, 3, 5, 7, 11, 13, 17, 19]
    nprime = 0
    factors = []
    while remainder != 1:
      if remainder%primes[nprime] == 0:
        factors.append(primes[nprime])
        remainder /= primes[nprime]
      else:
        nprime += 1
    return np.asarray(factors)

# TODO
#   add output file name as argument    (easy)
#   add support for pdm output rates    (easy)
#   add support for fractional rate convertions

def pcm_to_pdm(in_wav_file, out_pdm_file, pdm_sample_rate, verbose = False):

    pcm_sample_rate, pcm = scipy.io.wavfile.read(in_wav_file, 'r')

    nsamples = pcm.shape[0]

    multi_channel_pcm = pcm.T

    if len(multi_channel_pcm.shape ) == 1:
       multi_channel_pcm = np.reshape(multi_channel_pcm, (1, nsamples))

    # FIXME this need a handler for float types
    first_sample = multi_channel_pcm[0][0]
    if isinstance( first_sample, ( int, long, np.int16, np.int32 ) ):
      pcm_full_scale = np.iinfo(first_sample).max
      if verbose:
        print "Full scale PCM value: " + str(pcm_full_scale) + ' (Integer type PCM)'
    else:
      pcm_full_scale = 1.0
      if verbose:
        print "Full scale PCM value: " + str(pcm_full_scale) + ' (Float type PCM)'

    nchannels = multi_channel_pcm.shape[0]

    upsample_ratio , downsample_ratio = up_down_ratio(pcm_sample_rate, pdm_sample_rate)

    if nchannels > 8:
      print "Error: More than 8 channels is not supported, found " + str(nchannels) + "."
      return

    seconds = np.round(float(nsamples) / float(pcm_sample_rate), 3)

    if verbose:
      print "PCM -> PDM"
      print "Number of sample: " + str(nsamples) + ' ~ ' + str(seconds) + ' seconds.'
      print "Channel count: " + str(nchannels)
      print "Upsample ratio: " + str(upsample_ratio)
      print "Downsample ratio: " + str(downsample_ratio)

    # Stability limit
    pdm_magnitude_stability_limit = 0.4 # This seems to be safe

    output_length = int(nsamples*upsample_ratio/downsample_ratio)

    pdm_samples = np.zeros((8, output_length))

    max_abs_pcm_all_channels = 0.
    for ch in range(nchannels):
      if verbose:
        print 'processing channel ' + str(ch)
      pcm = multi_channel_pcm[ch]

      # limit the max pcm input to 0.4 - for stability of the modulator
      pcm = np.asarray(pcm, dtype=np.float64) / pcm_full_scale
      max_abs_pcm = max(abs(pcm))
      max_abs_pcm_all_channels = max(max_abs_pcm, max_abs_pcm_all_channels)
      if max_abs_pcm >= pdm_magnitude_stability_limit:

        pcm /= max(abs(pcm))
        pcm *= pdm_magnitude_stability_limit
        if verbose:
          print 'Abs max sample: '+ str(max_abs_pcm) +' limiting the abs max sample to 0.4'
      else :
        if verbose:
          print 'No sample limiting applied'
      # TODO do this in chunks to save memory
      up_sampled_pcm = signal.resample_poly(pcm, upsample_ratio, downsample_ratio)

      pdm_samples[ch] = delta_sigma_5th_order(up_sampled_pcm, output_length )

      # Write output to file
      # Convert from [-1, 1] -> [0, 1] range
      pdm_samples[ch] = (pdm_samples[ch]*0.5) + np.ones(len(pdm_samples[ch]))*0.5

    # pdm_samples = np.flip(pdm_samples, 0)
    pdm_samples = np.flipud(pdm_samples)

    my_bytes = np.array(pdm_samples, dtype=np.uint8)
    b = np.packbits(my_bytes.T, axis = -1)

    print "Max abs value {}".format(max_abs_pcm_all_channels)

    fp = open(out_pdm_file,'wb')

    b.tofile(fp)
    return

def butter_highpass(cutoff, fs, order=5):
    nyq = 0.5 * fs
    normal_cutoff = cutoff / nyq
    b, a = signal.butter(order, normal_cutoff, btype='high', analog=False)
    return b, a

def pdm_to_pcm(input_file, out_file, pdm_sample_rate, pcm_sample_rate,
               desired_max_abs,
               preserve_all_channels=False, verbose=False, apply_recording_conditioning=False):

    if verbose:
      print "PDM -> PCM"

    binary_file =  open(input_file, "rb")

    if verbose:
      print 'File length: ' + str(os.stat(input_file).st_size) + ' bytes'

    # Read the whole file at once
    input_data = bytearray(binary_file.read())

    nsamples = len(input_data)

    input_data = np.unpackbits(input_data)

    multi_channel_pdm =  np.reshape(input_data, (len(input_data)/8, -1)).T

    non_zero_channel = []
    if not preserve_all_channels:
      for ch in range(8):
        if sum(multi_channel_pdm[ch]) != 0:
          non_zero_channel.append(ch)
          if verbose:
            print 'Keeping channel ' + str(ch)
    else:
      for ch in range(8):
        non_zero_channel.append(ch)
        if verbose:
          print 'Keeping channel ' + str(ch)

    nchannels = len(non_zero_channel)

    upsample_ratio , downsample_ratio = up_down_ratio(pdm_sample_rate, pcm_sample_rate)

    seconds = np.round(float(nsamples) / float(pdm_sample_rate), 3)

    if verbose:
      print "Number of sample: " + str(nsamples) + ' ~ ' + str(seconds) + ' seconds.'
      print "Input rate: " + str(pdm_sample_rate) + 'Hz'
      print "Output rate: " + str(pcm_sample_rate) + 'Hz'
      print "Channel count: " + str(nchannels)
      print "Upsample ratio: " + str(upsample_ratio)
      print "Downsample ratio: " + str(downsample_ratio)

    pcm = np.zeros((nchannels, nsamples*upsample_ratio/downsample_ratio), dtype=np.float64)

    factors = get_prime_factors(downsample_ratio)

    factors = np.flipud(factors)

    for ch in range(nchannels):
      if verbose:
        print 'processing channel ' + str(ch)
      pdm_ch = non_zero_channel[ch]

      pdm = np.zeros(nsamples, dtype=np.float64)
      pdm = multi_channel_pdm[pdm_ch]*2.0
      pdm -= np.ones(len(multi_channel_pdm[ch]))

      # TODO do this in chunks to save memory
      if upsample_ratio != 1:
        t = signal.resample_poly(pdm, upsample_ratio, 1)
      else:
        t = pdm

      for f in factors:
        t = decimate(t, f, zero_phase = True, n = 21)

      pcm[ch] = t[:len(pcm[ch] )]


    if apply_recording_conditioning:

      # high pass filter to removed everything below 30Hz
      b, a = butter_highpass(30., pcm_sample_rate, order=5)
      for ch in range(nchannels):
        pcm[ch] = signal.filtfilt(b, a, pcm[ch], padlen = 1000, padtype='even')
        pcm[ch][0] = 0.0
        
    # Scale the output to the requested level
    m = np.amax(pcm) 

    # make it full scale
    pcm /= m
    pcm *= desired_max_abs

    scipy.io.wavfile.write(out_file, pcm_sample_rate, pcm.T)
    return

if __name__ == '__main__':
    parser = argparse.ArgumentParser( 'PDM and PCM converter.' )
    parser.add_argument( 'in_file' )
    parser.add_argument( 'out_file' )

    parser.add_argument( '--apply-conditioning', action='store_true',
                        help='30Hz high pass filter and gain.')

    parser.add_argument( '--output-rate', type=float, default=16000.0,
                        help='The sample rate out the output',
                        metavar='Hz')

    parser.add_argument( '--abs-pcm-value', type=float, default=1.0,
                        help='Maximum absolute value of output')

    parser.add_argument( '--verbose', action='store_true')
    parser.add_argument( '--make-pcm', action='store_true')


    args = parser.parse_args()

    verbose_enabled = args.verbose

    in_file = args.in_file
    out_file = args.out_file

    pdm_clock_rate = 3072000.0

    if verbose_enabled:
      print 'Input file: ' + str(in_file)
      print 'Output file: ' + str(out_file)

    if not args.make_pcm:
      pcm_to_pdm(in_file, out_file, pdm_clock_rate, verbose=verbose_enabled)
    else:

      apply_conditioning = args.apply_conditioning

      pdm_to_pcm(in_file, out_file, pdm_clock_rate, args.output_rate,
        args.abs_pcm_value,
        verbose=verbose_enabled,
        apply_recording_conditioning = apply_conditioning)

