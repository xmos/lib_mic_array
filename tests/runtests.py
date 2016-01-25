#!/usr/bin/env python
import xmostest

if __name__ == "__main__":
    xmostest.init()

    xmostest.register_group("lib_mic_array",
                            "lib_mic_array_frontend_tests",
                            "lib_mic_array frontend tests",
    """
Tests the lib_mic_array frontend, tests for:
 * channel cross talk
 * check for correct FIR coefficients on each channel
""")

    xmostest.register_group("lib_mic_array",
                            "lib_mic_array_backend_tests",
                            "lib_mic_array backend tests",
    """
Tests the lib_mic_array backend, tests for:
 * 4, 8, 12, and 16 channels
 * FIR compensation
 * microphone gain compensation values
 * microphone gain compensation enabled/disabled
 * deciamtion factors: 2, 4, 6, 8 and 12
 * overlapping and non-overlapping frames
 * windowing function application
 * frame size log2 of 0, 1, 2, 3 and 4
 * index bit reversal enabled/disbaled
 * NOT DC offset elimination
 * XTA elimination on unlinked code
""")

    xmostest.register_group("lib_mic_array",
                            "lib_mic_array_channel_ordering_tests",
                            "lib_mic_array channel ordering tests",
    """
Tests the lib_mic_array channel ordering, tests for:
 * check ``pdm_rx`` 4 and 8 channel orders
 * check ``decimate_to_pcm_4ch`` maintains channel ordering 
""")

    xmostest.runtests()

    xmostest.finish()
