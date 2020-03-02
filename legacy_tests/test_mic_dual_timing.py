#!/usr/bin/env python
# Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
import xmostest

class simple_pass_fail(xmostest.Tester):
    def __init__(self, product, group, test, config = {}, env = {}):
        super(simple_pass_fail, self).__init__()
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
        for line in output:
            if ("ERROR" in line) or ("Fail" in line) or ("FAIL" in line) or ("Error" in line):
                self.record_failure(line)

        xmostest.set_test_result(self.product, self.group, self.test, self.config, self.result,
                             output = output, env = self.env)


def do_test(testlevel):

    resources = xmostest.request_resource("xsim")

    tests = ["BLOCK_SIZE_1", "BLOCK_SIZE_240"]
    for test in tests:
        binary = 'test_mic_dual_timing/bin/{}/test_mic_dual_timing_{}.xe'.format(test, test)
        tester = simple_pass_fail('lib_mic_array', 'mic_dual', 'timing_{}_{}'.format(test, testlevel))
        xmostest.run_on_simulator(resources['xsim'], binary, tester = tester)


def runtest():
    do_test("smoke")
