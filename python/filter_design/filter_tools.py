# Copyright 2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pickle
import warnings

import numpy as np
import scipy.signal as spsig


# Use smallest float to avoid /0 errors
FLT_MIN = np.finfo(float).tiny


def db(x):
    """Convert a signal to decibels
    """
    return 20*np.log10(np.abs(x) + FLT_MIN)


def save_filter(out_path,  coeff_1, decimation_1, coeff_2, decimation_2):
    """save filter coefficients to a .pkl file in expected format
    """
    out_list = [[coeff_1, decimation_1], [coeff_2, decimation_2]]
    pickle.dump(out_list, open(out_path, 'wb'))
    return


def save_packed_filter(out_path,  out_list):
    """save filter coefficients to a .pkl file, assuming they are already in
    the packed format [stage][coefficients, decimation_ratio]
    """
    pickle.dump(out_list, open(out_path, 'wb'))
    return


def process_pdm(pdm_signal, coeffs):
    """Decimate a PDM signal using the packed coefficients in coeffs
    """
    signal = pdm_signal.astype(np.float64)
    for coeff in coeffs:
        signal = spsig.resample_poly(signal, 1, coeff[1], window=normalise_coeffs(coeff[0]))

    return signal


def normalise_coeffs(coeffs):
    """for unity gain at DC, just normalise by the sum of the coefficients
    """
    return coeffs.astype(np.float64)/np.sum(coeffs.astype(np.float64))


def moving_average_filter(decimation_ratio, n_stages):
    """a simple N stage moving average filter, floating point coefficients
    """

    kernel = np.ones(decimation_ratio, dtype=np.longdouble)
    kernel /= decimation_ratio
    b = np.copy(kernel)

    for n in range(n_stages-1):
        b = np.convolve(b, kernel)

    return b


def moving_average_filter_int16(decimation_ratio, n_stages, optimise_scaling=True):
    """a N stage moving average filter, implemented with int16 coefficients
    """
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
            # start with a 2 stage MA filter, scale and round before convolving
            # with the next stage. Use a 2 stage MA again for the final convolution
            rounding_stages = n_stages - 3
            if n_stages > 5:
                # rounding could add up to len(b) to the value, compensate scaling,
                # not all values have been tested, so some may fail
                if n_stages in [5]:
                    max_value = (32767.0 - len(b))
                elif n_stages in [7, 8]:
                    # hand tuned to get lucky on the rounding, there's probably a nicer way
                    max_value = (32767.0 - 7*len(b))
                else:
                    # sometimes adds up to more than len(b), add extra to be safe
                    max_value = (32767.0 - len(b)*n_stages)
            else:
                max_value = 32767.0
            scaling = np.max(b)/max_value
            stage_scaling = scaling**(1.0/rounding_stages)

            # start off with a 2 stage MA
            kernel_kernel = np.convolve(kernel, kernel)
            b = np.copy(kernel_kernel)

            # scale and round before convolving with the next stage
            for n in range(rounding_stages - 1):
                b = np.convolve(np.round(b/stage_scaling), kernel)

            # final stage is using the 2 stage MA again
            b = np.convolve(np.round(b/stage_scaling), kernel_kernel)
            b = b.astype(np.int64)
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
    """convert floating point coefficients to int32, simple scale and round
    """

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
    """Upsample the 2nd stage coefficients by the 1st stage filter

    The output coefficients are at the original sampling frequency.
    Could be done using spsig.resample_poly, but doesn't give the right length
    """
    f_new = np.zeros(len(coeff_2)*(decimation_1), dtype=np.longdouble)
    f_new[::decimation_1] = coeff_2
    coeff_combo = np.convolve(f_new, coeff_1)[:-(decimation_1-1)]

    return coeff_combo
