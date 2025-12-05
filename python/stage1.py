# Copyright 2022-2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import numpy as np
from mic_array.util import *
import sys
from pathlib import Path

import mic_array.filters as filters
import header_utils

"""
Emit C header content for the stage-1 decimator (PDM front-end).

This script loads a .pkl filter file, quantises and formats the stage1 coefficients to
the XCORE DUT expected format and prints the coefficient array and the filter params #defines.

Usage:
  python stage1.py <coef_pkl_file> -fp <prefix> [-fd <out_dir>]

If -fp is provided, a header <out_dir>/<prefix>.h is written and also echoed
to stdout. If -fp is omitted, content is printed to stdout only.

Refer to python/README.rst for more details.
"""

def main(coef_pkl_file, prefix="custom_filt", outstreams=[sys.stdout]):

  stage1, _ = filters.load(coef_pkl_file)

  out = header_utils.Tee(*outstreams)

  # get the byte array representing the binary matrix
  s1_coef_words = stage1.ToXCoreCoefArray()

  print("\n", file=out)
  print(f"#define {prefix.upper()}_STG1_DECIMATION_FACTOR   {stage1.DecimationFactor}", file=out)
  print(f"#define {prefix.upper()}_STG1_TAP_COUNT           {stage1.TapCount}", file=out)
  print(f"#define {prefix.upper()}_STG1_SHR                 0 /*shr not relevant for stage 1*/", file=out)

  print("\n", file=out)
  words = np.array(["0x%08X" % x for x in s1_coef_words], dtype=str).reshape((16,8))
  print(f"uint32_t {prefix}_stg1_coef[{len(s1_coef_words)}] = {{", file=out)

  for r in range(words.shape[0]):
    print("  " + ", ".join(words[r,:]) + ",", file=out)

  print("};", file=out)


if __name__ == "__main__":
  parser = header_utils.build_parser("stage1")
  args = parser.parse_args()
  print(f"stage1.py: coef_pkl_file = {args.coef_pkl_file}, file_prefix = {args.file_prefix}")

  if args.file_prefix:
    out_path = Path(args.file_dir) / f"{args.file_prefix}.h"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
      header_utils.print_header(args, [sys.stdout, f])
      main(args.coef_pkl_file, prefix=args.file_prefix, outstreams=[sys.stdout, f])
      header_utils.print_footer([sys.stdout, f])
  else:
    main(args.coef_pkl_file, outstreams=[sys.stdout])

