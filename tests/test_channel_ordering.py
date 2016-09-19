#!/usr/bin/env python
import xmostest, sys

def do_channel_ordering_test(test_name, port_width, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_channel_ordering/bin/{t}/test_channel_ordering_{t}.xe'.format(t=test_name)

    tester = xmostest.ComparisonTester(open('test_channel_ordering_{t}.expect'.format(t=test_name)),
                                       'lib_mic_array',
                                       'lib_mic_array_channel_ordering_tests',
                                       'channel_ordering_test_%s'%testlevel,
                                       {'config':test_name})

    tester.set_min_testlevel(testlevel)

    simargs = []
    if port_width == 8:
        simargs =  ("--plugin", "LoopbackPort.dll", "-port tile[0] XS1_PORT_8A 8 0 -port tile[0] XS1_PORT_8B 8 0 ")
    elif port_width == 4:
        simargs =  ("--plugin", "LoopbackPort.dll", "-port tile[0] XS1_PORT_8A 4 0 -port tile[0] XS1_PORT_4C 4 0 ",
                    "--plugin", "LoopbackPort.dll", "-port tile[0] XS1_PORT_8A 4 4 -port tile[0] XS1_PORT_4D 4 0 ")

        """
        simargs =  ("--plugin", "LoopbackPort.dll", "-port tile[0] XS1_PORT_8A 2 0 -port tile[0] XS1_PORT_4C 2 0 ",
                    "--plugin", "LoopbackPort.dll", "-port tile[0] XS1_PORT_8A 4 2 -port tile[0] XS1_PORT_4D 4 0 ",
                    "--plugin", "LoopbackPort.dll", "-port tile[0] XS1_PORT_8A 2 6 -port tile[0] XS1_PORT_4C 2 2 ")
        """
    else:
        print "ERROR: invalid port width specified = %d\n" % port_width 
        sys.exit(1)

    print simargs
    xmostest.run_on_simulator(resources['xsim'], binary,
                              simargs=simargs,
                              tester = tester)

def runtest():
    do_channel_ordering_test("FRONTEND_8BIT_4CH", 8, "smoke")
    do_channel_ordering_test("FRONTEND_8BIT_8CH", 8,  "smoke")
    do_channel_ordering_test("FRONTEND_4BIT_4CH", 4, "smoke")
    do_channel_ordering_test("FRONTEND_4BIT_8CH", 4, "smoke")
    #These are commented out because re-ordering test is not yet implemented
    #do_channel_ordering_test("FRONTEND_8BIT_4CH_CHANREORDER", 8,  "smoke")
    #do_channel_ordering_test("FRONTEND_8BIT_8CH_CHANREORDER", 8,  "smoke")
    #do_channel_ordering_test("FRONTEND_4BIT_4CH_CHANREORDER", 4,  "smoke")
    #do_channel_ordering_test("FRONTEND_4BIT_8CH_CHANREORDER", 4,  "smoke")
    #do_channel_ordering_test("BACKEND", "smoke")
