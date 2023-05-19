# Copyright 2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pickle
import warnings

import numpy as np
import scipy.signal as spsig


FLT_MIN = np.finfo(float).tiny


def db(x):
    return 20*np.log10(np.abs(x) + FLT_MIN)


def save_filter(out_path,  coeff_1, decimation_1, coeff_2, decimation_2):
    out_list = [[coeff_1, decimation_1], [coeff_2, decimation_2]]
    pickle.dump(out_list, open(out_path, 'wb'))
    return


def save_packed_filter(out_path,  out_list):
    pickle.dump(out_list, open(out_path, 'wb'))
    return


def process_pdm(pdm_signal, coeffs):
    signal = pdm_signal.astype(np.float64)
    for coeff in coeffs:
        signal = spsig.resample_poly(signal, 1, coeff[1], window=normalise_coeffs(coeff[0]))

    return signal


def normalise_coeffs(coeffs):
    # for unity gain at DC, just normalise by the sum of the coefficients

    return coeffs.astype(np.float64)/np.sum(coeffs.astype(np.float64))


def optimise_int16_scaling(coeffs, decimation_ratio):

    print("running brute force int16 scaler")

    nfft = 1024
    float_coeffs = coeffs.astype(np.longfloat)

    min_err = np.inf
    best_scale = 0
    best_quant = np.round
    errors = []
    for scale in np.arange(2**14, 2**15):
        for quant in [np.round, np.ceil, np.floor]:
            # scale and quantize coeffients
            scaled = float_coeffs * (scale/(np.max(float_coeffs)))
            scaled = quant(scaled)

            # calculate frequency response
            _, response = spsig.freqz(normalise_coeffs(scaled), worN=nfft*decimation_ratio)
            ars = np.abs(response)

            # calculate magnitude of aliases
            response_decim = np.zeros_like(ars[:nfft])
            for n in range(1, decimation_ratio):
                if n % 2 == 0:
                    response_decim += ars[n*nfft:(n+1)*nfft]
                else:
                    response_decim += np.flip(ars[n*nfft:(n+1)*nfft])

            # average level in final passband (ish)
            error = np.sum(response_decim[:256])

            errors.append(error)
            if error < min_err:
                min_err = error
                best_scale = scale
                best_quant = quant

    coeffs = best_quant(float_coeffs * (best_scale/(np.max(float_coeffs))))
    print("best scaling: %d, best quant: %s" % (best_scale, best_quant.__name__))

    return coeffs.astype(np.int64)


def moving_average_filter(decimation_ratio, n_stages):
    # a simple N stage moving average filter, floating point

    kernel = np.ones(decimation_ratio, dtype=np.longdouble)
    kernel /= decimation_ratio
    b = np.copy(kernel)

    for n in range(n_stages-1):
        b = np.convolve(b, kernel)

    return b


def moving_average_filter_int16(decimation_ratio, n_stages, optimise_scaling=True):
    # a N stage moving average filter, implemented with int16 coefficients

    # start in int64 so we don't overflow straight away
    kernel = np.ones(decimation_ratio, dtype=np.int64)
    b = np.copy(kernel)

    for n in range(n_stages-1):
        b = np.convolve(b, kernel)

    # we expect all positive coefficients, so anything negative means we've overflowed
    assert np.all(b > 0), "max filter coefficient > 2^63, try reducing number of stages"

    # check no coefficients are too big
    if np.max(b) > 2**15:
        warnings.warn("max filter coefficient > 2^15, scaling coefficients, some may be lost")

        # if they are too big, scale coefficients
        if optimise_scaling:
            b = optimise_int16_scaling(b, decimation_ratio)
        else:
            b = np.multiply(b, (2**15 - 1)/np.max(b), dtype=np.longdouble)
            b = np.fix(b).astype(np.int64)

        assert np.max(b) < 2**15

    # check max output isn't too big
    if np.sum(b) > 2**31:
        warnings.warn("sum filter coefficient > 2^31, scaling coefficients, some may be lost")

        # if they are too big, keep shifting coefficients until they aren't
        while np.sum(b) > 2**31:
            b = b // 2

        assert np.sum(b) < 2**31

    # convert to int16 and final checks
    b16 = b.astype(np.int16)
    assert np.all(b == b16)
    assert np.all(b >= 0)

    # remove leading and trailing zeros
    b16 = b16[b16 > 0]

    return b16


def float_coeffs_to_int32(b):

    # scale to int32 level, subtract 1 to avoid overflow at max
    max_coeff = np.max(b)
    b = b/max_coeff * (2**31 - 1)

    sum_limit = 2**40
    # check max output isn't too big
    if np.sum(np.abs(b)) > sum_limit:
        warnings.warn("sum filter coefficient > 2^%d, scaling coefficients, some may be lost" % np.log2(sum_limit))

        b *= (sum_limit - 1)/np.sum(np.abs(b))

        assert np.sum(np.abs(b)) < sum_limit

    b = np.round(b).astype(np.int32)
    assert np.sum(np.abs(b)) < sum_limit
    b = np.trim_zeros(b)

    return b


def combined_filter(coeff_1, coeff_2, decimation_1):
    # Upsample the 2nd stage coefficients by the 1st stage filter
    # The output coefficients are at the original sampling frequency.
    # Could be done using spsig.resample_poly, but doesn't give the right length
    f_new = np.zeros(len(coeff_2)*(decimation_1), dtype=np.longdouble)
    f_new[::decimation_1] = coeff_2
    coeff_combo = np.convolve(f_new, coeff_1)[:-(decimation_1-1)]

    return coeff_combo
