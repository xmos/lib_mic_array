#!/usr/bin/env python
# Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
# This software is available under the terms provided in LICENSE.txt.
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
