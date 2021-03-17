#!/usr/bin/env python
# Copyright 2016-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import xmostest

def do_test(testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_lib_include/bin/test_lib_include.xe'

    tester = xmostest.ComparisonTester(open('test_lib_include.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_backend_tests',
                                       'lib_include_test_%s'%testlevel )

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              tester = tester)

def runtest():
    do_test("smoke")
