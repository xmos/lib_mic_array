# Copyright 2023-2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import filter_design.plot_coeffs as pc
import filter_design.design_filter as df
from pathlib import Path


def test_design_filter():
    df.main()


def test_plot_coeffs():
    pc.main(Path(__file__).parent / ".." / "BasicMicArray" / "small_2_stage_filter_int.pkl")


if __name__ == "__main__":
    test_design_filter()
