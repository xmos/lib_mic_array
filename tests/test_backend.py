#!/usr/bin/env python
import xmostest

def do_backend_test(frame_count, testlevel):

    # Check if the test is running in an environment with hardware resources
    # available - the test takes a long time to run in the simulator
    args = xmostest.getargs()
    if not args.remote_resourcer:
        # Abort the test
        return

    binary = 'test_fir_model/bin/COUNT{fc}/test_fir_model_COUNT{fc}.xe'.format(fc=frame_count)

    tester = xmostest.ComparisonTester(open('fir_model.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_backend_tests',
                                       'backend_test_%s'%testlevel,
                                       {'frame_count':frame_count})

    tester.set_min_testlevel(testlevel)

    resources = xmostest.request_resource("uac2_xcore200_mc_testrig_os_x_11",
                                          tester)

    run_job = xmostest.run_on_xcore(resources['analysis_device_1'],
                                    binary,
                                    tester=tester)

    xmostest.complete_all_jobs()

def runtest():
    do_backend_test(4, "smoke")
    do_backend_test(64, "nightly")
