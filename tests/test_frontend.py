#!/usr/bin/env python
import xmostest

def do_frontend_test(channel_count, port_width, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_pdm_interface/bin/CH{ch}_{pw}B/test_pdm_interface_CH{ch}_{pw}B.xe'.format(ch=channel_count, pw=port_width)

    tester = xmostest.ComparisonTester(open('pdm_interface.expect'),
                                       'lib_mic_array',
                                       'lib_mic_array_frontend_tests',
                                       'frontend_test_%s'%testlevel,
                                       {'channel_count':channel_count, 'port_width':port_width})

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simargs=[],
                              tester = tester)

def _runtest():
    for channel_count in (4, 8):
        for port_width in (4, 8):
            do_frontend_test(channel_count, port_width, "smoke")

def runtest():
    do_frontend_test(4, 4, "smoke")

xmostest.init()

xmostest.register_group("lib_mic_array",
                            "lib_mic_array_frontend_tests",
                            "lib_mic_array frontend tests", "blag")
runtest()