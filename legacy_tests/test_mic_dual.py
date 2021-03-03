#!/usr/bin/env python
# Copyright (c) 2016-2021, XMOS Ltd, All rights reserved
# This software is available under the terms provided in LICENSE.txt.
import xmostest
import subprocess
import sys, os
sys.path.append("test_mic_dual")
from pcm_to_pdm import pcm_to_pdm
from thdncalculator import analyze_channels, THDN, rms_flat
from multiprocessing import Process
import numpy as np
from scipy.signal import welch
import soundfile as sf

test_dir = "test_mic_dual/"
target_snr = -104.0     # SNR in dB. We be getting -104.8 or nearest offer for 0.55 FSD
target_ratio = 0.9999   # Ratio between RMS signal amplitudes of normal and dual mic_array
AUDIO_LENGTH_S = 1.0    # Have found that 1s, 4s, 10s gets a fair result. Others may cut at non-zero cross
closeness = 0.015       # Relative closeness between spectral responses of mic_array and dual

#These are the names of the files that get spat out of the sim. 
out_files = ["ch_a_std.wav", "ch_b_std.wav", "ch_a_dual.wav", "ch_b_dual.wav"]

class THD_N_Tester(xmostest.Tester):
    def __init__(self, target_snr, product, group, test, config = {}, env = {}):
        super(THD_N_Tester, self).__init__()
        self.target_snr = target_snr
        self.register_test(product, group, test, config)
        self.product = product
        self.group = group
        self.test = test
        self.config = config
        self.env = env
        self.result = True

    def record_failure(self, failure_reason):
        # Append a newline if there isn't one already
        if not failure_reason.endswith('\n'):
            failure_reason += '\n'
        self.failures.append(failure_reason)
        print ("ERROR: %s" % failure_reason), # Print without newline
        self.result = False

    def run(self, output):
        add_wav_headers(out_files)
        results = [analyze_channels(test_dir + test_file, THDN) for test_file in out_files]
        for result, out_file in zip(results, out_files):
            if result > self.target_snr:
                self.record_failure(out_file + " SNR is {}dB which is worse than target of {}dB".format(result, self.target_snr))
        xmostest.set_test_result(self.product, self.group, self.test, self.config, self.result,
                             output = output, env = self.env)

class Spectral_Tester(xmostest.Tester):
    def __init__(self, closeness, product, group, test, config = {}, env = {}):
        super(Spectral_Tester, self).__init__()
        self.closeness = closeness
        self.register_test(product, group, test, config)
        self.product = product
        self.group = group
        self.test = test
        self.config = config
        self.env = env
        self.result = True

    def get_fft(self, wav_file):
        audio_data, fs = sf.read(test_dir+wav_file)
        f, Pxx_spec = welch(audio_data, fs, 'flattop', 512, scaling='spectrum')
        # Ditch anything above 7.0kHz or below 100Hz
        idxs = np.where(f < 7000)
        idxs = np.where(f[idxs] > 100)
        return f[idxs], np.sqrt(Pxx_spec[idxs])

    def record_failure(self, failure_reason):
        # Append a newline if there isn't one already
        if not failure_reason.endswith('\n'):
            failure_reason += '\n'
        self.failures.append(failure_reason)
        print ("ERROR: %s" % failure_reason), # Print without newline
        self.result = False

    def run(self, output):
        add_wav_headers(out_files)
        for i in range(2):     
            result = np.isclose(self.get_fft(out_files[i]), self.get_fft(out_files[i+2]), rtol=self.closeness)
            if not result.all():
                self.record_failure("Spectral response deviates between {} and {}: \n{}".format(out_files[i], out_files[i+2], result))
        xmostest.set_test_result(self.product, self.group, self.test, self.config, self.result,
                             output = output, env = self.env)

class rms_tester(xmostest.Tester):
    def __init__(self, max_variance, product, group, test, config = {}, env = {}):
        super(rms_tester, self).__init__()
        self.max_variance = max_variance
        self.register_test(product, group, test, config)
        self.product = product
        self.group = group
        self.test = test
        self.config = config
        self.env = env
        self.result = True

    def record_failure(self, failure_reason):
        # Append a newline if there isn't one already
        if not failure_reason.endswith('\n'):
            failure_reason += '\n'
        self.failures.append(failure_reason)
        print ("ERROR: %s" % failure_reason), # Print without newline
        self.result = False

    def run(self, output):
        add_wav_headers(out_files)
        results = [analyze_channels(test_dir + test_file, rms_flat) for test_file in out_files]
        ch_a_dual_std_ratio = results[0] / results[2]
        ch_b_dual_std_ratio = results[1] / results[3]
        ch_a_dual_std_ratio = 1 / ch_a_dual_std_ratio if ch_a_dual_std_ratio > 1 else ch_a_dual_std_ratio
        ch_b_dual_std_ratio = 1 / ch_b_dual_std_ratio if ch_b_dual_std_ratio > 1 else ch_b_dual_std_ratio

        if ch_a_dual_std_ratio < target_ratio or ch_b_dual_std_ratio < target_ratio:
            self.record_failure("RMS amplitudes of ch_a {} & ch_b {} of dual too different from mic_array. Raw results: {}".format(ch_a_dual_std_ratio, ch_b_dual_std_ratio, results))
        else:
            print("RMS amplitude differences for ch_a: {} & ch_b: {}".format(ch_a_dual_std_ratio, ch_b_dual_std_ratio) )
        xmostest.set_test_result(self.product, self.group, self.test, self.config, self.result,
                             output = output, env = self.env)

def do_mic_dual_test(testlevel, checker):
    resources = xmostest.request_resource("axe")

    if checker == THDN:
        tester = THD_N_Tester(target_snr, 'lib_mic_array', 'mic_dual', 'thd_noise_{}'.format(testlevel))
    elif checker == rms_flat:
        tester = rms_tester(target_snr, 'lib_mic_array', 'mic_dual', 'amplitude_{}'.format(testlevel))
    elif checker == Spectral_Tester.get_fft:
        tester = Spectral_Tester(closeness, 'lib_mic_array', 'mic_dual', 'spectral_{}'.format(testlevel))
    else:
        fail("No checker passed to do_mic_dual_test")

    tester.set_min_testlevel(testlevel)

    binary = 'test_mic_dual/bin/test_mic_dual.xe'
    xmostest.run_on_simulator(resources['axe'], binary,
                              simargs=[],
                              tester=tester)
    xmostest.complete_all_jobs()


# Expects a tuple of length two of arg list
def create_test_pdm_signals(sox_args):
    in_file_names = ["ch_a_src.wav", "ch_b_src.wav"]
    out_file_names = ["ch_a.pdm", "ch_b.pdm"]

    cmd = "sox -n -c 1 -b 32 -r 16000 {} synth"

    for sox_arg, file_name in zip(sox_args, in_file_names):
        this_cmd = cmd.format(test_dir + file_name).split()
        this_cmd.append(str(AUDIO_LENGTH_S))
        this_cmd.extend(sox_arg)
        print(" ".join(this_cmd))
        subprocess.call(this_cmd)

    # Run in parallel
    def ptp0():
        pcm_to_pdm(test_dir + in_file_names[0], test_dir + out_file_names[0], 3072000, verbose = True)
    def ptp1():
        pcm_to_pdm(test_dir + in_file_names[1], test_dir + out_file_names[1], 3072000, verbose = True)
    proc = []
    for fn in [ptp0, ptp1]:
        p = Process(target=fn)
        p.start()
        proc.append(p)
    for p in proc:
        p.join()


def add_wav_headers(file_list):
    STARTUP_TRIM_LENGTH_S=0.1 #0.1 is enough to remove the startup glitch and seems to cut at zero cross (good for THD)

    cmd = "sox --endian little -c 1 -r 16000 -b 32 -e signed-integer {} {} trim {}"
    for out_name in file_list:
        in_name = out_name.rstrip(".wav") + ".raw"
        this_cmd = cmd.format(test_dir + in_name, test_dir + out_name, STARTUP_TRIM_LENGTH_S)
        subprocess.call(this_cmd.split())

def cleanup_files():
    files = os.listdir(test_dir)
    tmp_audio_files = [i for i in files if i.endswith('.wav') or i.endswith('.raw') or i.endswith('.pdm')]
    for tmp_file in tmp_audio_files:
        del_this = test_dir+tmp_file
        os.remove(del_this)

def runtest():
    create_test_pdm_signals((["sine", "300"], ["sine", "1000"]))
    do_mic_dual_test("smoke", THDN)
    
    # re-use the previous sine pdm signals
    do_mic_dual_test("smoke", rms_flat)

    create_test_pdm_signals((["whitenoise"], ["white"]))
    do_mic_dual_test("smoke", Spectral_Tester.get_fft)
    
    cleanup_files()


