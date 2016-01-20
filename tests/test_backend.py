#!/usr/bin/env python
import xmostest

def do_backend_test(frame_count, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_fir_model/bin/COUNT{fc}/test_fir_model_COUNT{fc}.xe'.format(fc=frame_count)

    tester = xmostest.ComparisonTester(open('fir_model.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_backend_tests',
                                       'basic_test_%s'%testlevel,
                                       {'frame_count':frame_count})

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simargs=[],
                              tester = tester)

def runtest():
    do_backend_test(4, "smoke")
    do_backend_test(64, "nightly")

