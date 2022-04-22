# Copyright 2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import pickle as pkl
import numpy as np
import filters


coef_file = "coef/32_6_257_65.pkl"

_, stage2 = filters.load(coef_file, truncate_s1=True)


print(f"Scale: {stage2.ScaleInt32}")

print(f"Right-shift: {stage2.ShrInt32}")


print("\n")
print("{" + ", ".join( [f"{x}" for x in stage2.CoefInt32] ) + "}")