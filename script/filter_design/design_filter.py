# Copyright 2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import numpy as np
import scipy.signal as spsig

try:
    # for pytest
    from . import filter_tools as ft
except ImportError:
    import filter_tools as ft


class stage_params(object):
    def __init__(self, cutoff, transition_bandwidth, taps, fir_window):
        self.cutoff = cutoff
        self.transition_bw = transition_bandwidth
        self.taps = taps
        self.fir_window = fir_window


def design_2_stage(fs_0, decimations, ma_stages, stage_2: stage_params, int_coeffs=False, 
                   compensate_s1=True):

    # calculate intermediate sample rates
    fses = fs_0 * np.ones(len(decimations) + 1)
    for n in range(len(decimations)):
        fses[n+1:] /= decimations[n]

    # design stage 1
    if int_coeffs:
        coeff_1 = ft.moving_average_filter_int16(decimations[0], ma_stages)
    else:
        coeff_1 = ft.moving_average_filter(decimations[0], ma_stages)

    # design stage 2
    if compensate_s1:
        # compensate for rolloff in stage 1
        norm_coeff_1 = ft.normalise_coeffs(coeff_1)
        w, response = spsig.freqz(norm_coeff_1, fs=fses[0], worN=1024*decimations[0])
        freqs = w[w <= stage_2.cutoff - stage_2.transition_bw/2]
        gains = 1 / np.abs(response[:len(freqs)])
    else:
        freqs = [0, stage_2.cutoff - stage_2.transition_bw/2]
        gains = [1, 1]

    # add stopband filter points, design filter using windowed FIR method
    freqs = np.concatenate((freqs, np.array((stage_2.cutoff + stage_2.transition_bw/2, 0.5*fses[1]))))
    gains = np.concatenate((gains, np.zeros(2)))
    coeff_2 = spsig.firwin2(stage_2.taps, freqs, gains, window=stage_2.fir_window, fs=fses[1])

    if int_coeffs:
        coeff_2 = ft.float_coeffs_to_int32(coeff_2)

    coeffs = [[coeff_1, decimations[0]], [coeff_2, decimations[1]]]

    return coeffs


def design_3_stage(fs_0, decimations, ma_stages, stage_2: stage_params, stage_3: stage_params, int_coeffs=False):

    # calculate intermediate sample rates
    fses = fs_0 * np.ones(len(decimations) + 1)
    for n in range(len(decimations)):
        fses[n+1:] /= decimations[n]

    # design stage 1
    if int_coeffs:
        coeff_1 = ft.moving_average_filter_int16(decimations[0], ma_stages)
    else:
        coeff_1 = ft.moving_average_filter(decimations[0], ma_stages)

    # design stage 2
    if decimations[1] == 2 and ((stage_2.taps - 3)/2 % 2 == 0):
        # if taps-3 is a multiple of 4, we can design the filter at the lower
        # sampling frequency and get perfect zeros in every other coefficient
        # (except the middle). See
        # https://tomverbeure.github.io/2020/12/15/Half-Band-Filters-A-Workhorse-of-Decimation-Filters.html

        # design a half band filter at the lower fs
        freqs = [0, stage_2.cutoff, 0.5*fses[2]]
        gains = [1, 1, 0]
        coeff_2_half = spsig.firwin2((stage_2.taps + 1)//2, freqs, gains, window=stage_2.fir_window, fs=fses[2])
        # interleave zeros and half magnitude to upsample
        coeff_2 = np.zeros(stage_2.taps)
        coeff_2[::2] = coeff_2_half/2
        coeff_2[stage_2.taps//2] = 0.5

    else:
        # simple windowed FIR if we can't use the trick
        freqs = [0, stage_2.cutoff - stage_2.transition_bw/2, 0.5*fses[1] - stage_2.cutoff - stage_2.transition_bw/2, 0.5*fses[1]]
        gains = [1, 1, 0, 0]
        coeff_2 = spsig.firwin2(stage_2.taps, freqs, gains, window=stage_2.fir_window, fs=fses[1])

    # design stage 3
    # calculate combined response of previous stages
    c1_n = ft.normalise_coeffs(coeff_1)
    c2_n = ft.normalise_coeffs(coeff_2)
    coeff_combo = ft.combined_filter(c1_n, c2_n, decimations[0])

    # compensate for rolloff in stage 1 and 2
    w, response = spsig.freqz(coeff_combo, fs=fses[0], worN=1024*decimations[0]*decimations[1])
    freqs = w[w <= stage_3.cutoff - stage_3.transition_bw/2]
    gains = 1 / np.abs(response[:len(freqs)])

    # add stopband filter points, design filter using windowed FIR method
    freqs = np.concatenate((freqs, np.array((stage_3.cutoff + stage_3.transition_bw/2, 0.5*fses[2]))))
    gains = np.concatenate((gains, np.zeros(2)))
    coeff_3 = spsig.firwin2(stage_3.taps, freqs, gains, window=stage_3.fir_window, fs=fses[2])

    if int_coeffs:
        coeff_2 = ft.float_coeffs_to_int32(coeff_2)
        coeff_3 = ft.float_coeffs_to_int32(coeff_3)

    coeffs = [[coeff_1, decimations[0]], [coeff_2, decimations[1]], [coeff_3, decimations[2]]]

    return coeffs


def small_2_stage_filter(int_coeffs):
    # These coefficients have been chosen to minimise the number of taps, for
    # use in resource constrained systems. Alias suppression is reduced, and
    # the passband rolls off above 6kHz

    # sample rates and decimations
    fs_0 = 3072000
    decimations = [32, 6]

    # stage 1 parameters
    ma_stages = 4

    # stage 2 parameters
    cutoff = 7500
    transition_bandwidth = 0
    taps_2 = 64
    fir_window = ("kaiser", 5)
    stage_2 = stage_params(cutoff, transition_bandwidth, taps_2, fir_window)

    coeffs = design_2_stage(fs_0, decimations, ma_stages, stage_2, int_coeffs=int_coeffs)

    return coeffs


def good_2_stage_filter(int_coeffs):
    # These coefficients have been chosen for good performance. The filter
    # attenuation and rolloff is good, at the cost of a higher number of taps
    # than the adequate filter.

    # sample rates and decimations
    fs_0 = 3072000
    decimations = [32, 6]

    # stage 1 parameters
    ma_stages = 4

    # stage 2 parameters
    cutoff = 7800
    transition_bandwidth = 0
    taps_2 = 256
    fir_window = ("kaiser", 8)
    stage_2 = stage_params(cutoff, transition_bandwidth, taps_2, fir_window)

    coeffs = design_2_stage(fs_0, decimations, ma_stages, stage_2, int_coeffs=int_coeffs)

    return coeffs


def good_3_stage_filter(int_coeffs):
    # These coefficients have been chosen for good performance. The extra
    # decimation stage means fewer taps are needed than the 2 stage filter, at
    # the cost of more complexity.

    # sample rates and decimations
    fs_0 = 3072000
    decimations = [32, 2, 3]

    # stage 1 parameters
    ma_stages = 4

    # stage 2 parameters
    cutoff = 16000
    transition_bandwidth = 0
    taps_2 = 19
    fir_window = ("kaiser", 5)
    stage_2 = stage_params(cutoff, transition_bandwidth, taps_2, fir_window)

    # stage 3 parameters
    cutoff = 7750
    transition_bandwidth = 500
    taps_3 = 96
    fir_window = ("kaiser", 7)
    stage_3 = stage_params(cutoff, transition_bandwidth, taps_3, fir_window)

    coeffs = design_3_stage(fs_0, decimations, ma_stages, stage_2, stage_3, int_coeffs=int_coeffs)

    return coeffs


def good_32k_filter(int_coeffs):
    # These coefficients are designed for decimation to 32kHz.
    # PDM mics often have a resonance towards to top of the audible band (e.g.
    # Infineon IM69D130 has a resonance at 16.5kHz), so the filter beings to
    # roll off above 12.5kHz to compensate for this.
    # Due to the wider final passband, a higher order MA filter is needed for
    # stage 1 than for a 16kHz mic array

    # sample rates and decimations
    fs_0 = 3072000
    decimations = [32, 3]

    # stage 1 parameters
    ma_stages = 5

    # stage 2 parameters
    cutoff = 14500
    transition_bandwidth = 1000
    taps_2 = 96
    fir_window = ("kaiser", 6.5)
    stage_2 = stage_params(cutoff, transition_bandwidth, taps_2, fir_window)

    coeffs = design_2_stage(fs_0, decimations, ma_stages, stage_2, int_coeffs=int_coeffs)

    return coeffs


def main():
    coeffs = small_2_stage_filter(int_coeffs=True)
    out_path = "small_2_stage_filter_int.pkl"
    ft.save_packed_filter(out_path, coeffs)

    coeffs = good_2_stage_filter(int_coeffs=True)
    out_path = "good_2_stage_filter_int.pkl"
    ft.save_packed_filter(out_path, coeffs)

    coeffs = good_3_stage_filter(int_coeffs=True)
    out_path = "good_3_stage_filter_int.pkl"
    ft.save_packed_filter(out_path, coeffs)

    coeffs = good_32k_filter(int_coeffs=True)
    out_path = "good_32k_filter_int.pkl"
    ft.save_packed_filter(out_path, coeffs)


if __name__ == "__main__":
    main()
