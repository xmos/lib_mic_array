#!/usr/bin/env python
# Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
import xmostest

def do_backend_test(length, frame_count, testlevel):

    # Check if the test is running in an environment with hardware resources
    # available - the test takes a long time to run in the simulator
    args = xmostest.getargs()
    if not args.remote_resourcer:
        # Abort the test
        print 'remote resourcer not avaliable'
        return

    binary = 'test_fir_model/bin/COUNT{fc}_{len}/test_fir_model_COUNT{fc}_{len}.xe'.format(fc=frame_count, len=length)

    tester = xmostest.ComparisonTester(open('fir_model.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_backend_tests',
                                       'backend_test_%s'%testlevel,
                                       {'frame_count':frame_count, 'length':length})

    tester.set_min_testlevel(testlevel)

    resources = xmostest.request_resource("testrig_os_x_12",
                                          tester)

    run_job = xmostest.run_on_xcore(resources['uac2_xcore200_mc_analysis_device_1'],
                                    binary,
                                    tester=tester, timeout=3600)

    xmostest.complete_all_jobs()

def runtest():
    do_backend_test('LONG', 4, "smoke")
    do_backend_test('SHORT', 4, "smoke")
    do_backend_test('LONG', 64, "nightly")
    do_backend_test('SHORT', 64, "nightly")
