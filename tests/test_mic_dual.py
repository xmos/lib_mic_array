#!/usr/bin/env python
# Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
import xmostest
import subprocess
import sys, os
sys.path.append("test_mic_dual")
from pcm_to_pdm import pcm_to_pdm
from thdncalculator import analyze_channels, THDN, rms_flat
from multiprocessing import Process

test_dir = "test_mic_dual/"
target_snr = -102.0 # SNR in dB. We be getting -120.7 or nearest offer
AUDIO_LENGTH_S = 4 #Have found we need a good 4s to get a fair result


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
        out_files = ["ch_a_std.wav", "ch_b_std.wav", "ch_a_dual.wav", "ch_b_dual.wav"]
        add_wav_headers(out_files)
        results = [analyze_channels(test_dir + test_file, THDN) for test_file in out_files]
        for result, out_file in zip(results, out_files):
            if result > self.target_snr:
                self.record_failure(out_file + " SNR is {}dB which is worse than target of {}dB".format(result, self.target_snr))
        xmostest.set_test_result(self.product, self.group, self.test, self.config, self.result,
                             output = output, env = self.env)


def do_mic_dual_test(testlevel, checker):
    resources = xmostest.request_resource("axe")

    tester = THD_N_Tester(target_snr, 'lib_mic_array', 'mic_dual', 'thd_noise_{}'.format(testlevel))

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
        print(del_this)
        os.remove(del_this)

def runtest():
    create_test_pdm_signals((["sine", "300"], ["sine", "1000"]))
    do_mic_dual_test("smoke", THDN)
    cleanup_files()


