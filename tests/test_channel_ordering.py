#!/usr/bin/env python
# Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
import xmostest

def do_channel_ordering_test(test_name, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_channel_ordering/bin/{t}/test_channel_ordering_{t}.xe'.format(t=test_name)

    tester = xmostest.ComparisonTester(open('test_channel_ordering_{t}.expect'.format(t=test_name)),
                                       'lib_mic_array',
                                       'lib_mic_array_channel_ordering_tests',
                                       'channel_ordering_test_%s'%testlevel,
                                       {'config':test_name})

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simargs=["--plugin", "LoopbackPort.dll",  "-port tile[0] XS1_PORT_8A 8 0 -port tile[0] XS1_PORT_8B 8 0 "],
                              tester = tester)

def runtest():
    do_channel_ordering_test("FRONTEND_8BIT_4CH", "smoke")
    do_channel_ordering_test("FRONTEND_8BIT_8CH", "smoke")
    do_channel_ordering_test("FRONTEND_8BIT_4CH_CHANREORDER", "smoke")
    do_channel_ordering_test("FRONTEND_8BIT_8CH_CHANREORDER", "smoke")
    do_channel_ordering_test("BACKEND", "smoke")
