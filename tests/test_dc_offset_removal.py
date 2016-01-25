#!/usr/bin/env python
import xmostest

def do_dc_offset_removal_test(testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_dc_offset_removal/bin/test_dc_offset_removal.xe'

    tester = xmostest.ComparisonTester(open('test_dc_offset_removal.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_backend_tests',
                                       'dc_offset_removal_test_%s'%testlevel)

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simargs=[],
                              tester = tester)

def runtest():
    do_dc_offset_removal_test("smoke")
