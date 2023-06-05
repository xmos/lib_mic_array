# Copyright 2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pytest
import matplotlib.pyplot as plt


@pytest.fixture(autouse=True)
def no_plots(monkeypatch):
    # if a plot is shown it will hang pytest until it is closed- fine if running locally but a
    # problem on Jenkins! This code overloads plt.show() to plt.close('all') if pytest is not
    # running on windows.
    def no_show():
        print("Not showing plot, see conftest.py for details")
        plt.close("all")

    if True:
        print("monkeypatching plt.show()")
        monkeypatch.setattr("matplotlib.pyplot.show", no_show)
