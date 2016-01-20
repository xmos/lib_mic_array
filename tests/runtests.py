#!/usr/bin/env python
import xmostest

if __name__ == "__main__":
    xmostest.init()

    xmostest.register_group("lib_mic_array",
                            "lib_mic_array_frontend_tests",
                            "lib_mic_array frontend tests",
    """
Tests the lib_mic_array frontend.
""")

    xmostest.register_group("lib_mic_array",
                            "lib_mic_array_backend_tests",
                            "lib_mic_array backend tests",
    """
Tests the lib_mic_array backend.
""")

    xmostest.runtests()

    xmostest.finish()
