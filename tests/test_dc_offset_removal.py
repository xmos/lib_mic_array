#!/usr/bin/env python
import xmostest

def do_dc_offset_removal_test(testlevel):

    # Check if the test is running in an environment with hardware resources
    # available - the test takes a long time to run in the simulator
    args = xmostest.getargs()
    if not args.remote_resourcer:
        # Abort the test
        print 'remote resourcer not avaliable'
        return

    binary = 'test_dc_offset_removal/bin/test_dc_offset_removal.xe'

    tester = xmostest.ComparisonTester(open('test_dc_offset_removal.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_backend_tests',
                                       'dc_offset_removal_test_%s'%testlevel)

    tester.set_min_testlevel(testlevel)

    resources = xmostest.request_resource("testrig_os_x_12",
                                          tester)

    run_job = xmostest.run_on_xcore(resources['uac2_xcore200_mc_analysis_device_1'],
                                    binary,
                                    tester=tester)

    xmostest.complete_all_jobs()

def runtest():
    do_dc_offset_removal_test("smoke")
