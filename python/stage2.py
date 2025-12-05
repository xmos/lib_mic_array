# Copyright 2022-2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

from mic_array.util import *
import matplotlib.pyplot as plt
import sys
from pathlib import Path

import mic_array.filters as filters
import header_utils

"""
Emit C header content for the stage-2 decimator (PCM FIR stage).

This script loads a .pkl filter file, quantises and formats the stage2 coefficients to
the XCORE DUT expected format and prints the coefficient array and the filter params #defines.

Usage:
  python stage2.py <coef_pkl_file> -fp <prefix> [-fd <out_dir>]

If -fp is provided, a header <out_dir>/<prefix>.h is written and also echoed
to stdout. If -fp is omitted, content is printed to stdout only.

Refer to python/README.rst for more details and examples.
"""

def main(coef_pkl_file, prefix="custom_filt", outstreams=[sys.stdout]):

  _, stage2 = filters.load(coef_pkl_file)

  out = header_utils.Tee(*outstreams)
  print("\n", file=out)
  print(f"#define {prefix.upper()}_STG2_DECIMATION_FACTOR   {stage2.DecimationFactor}", file=out)
  print(f"#define {prefix.upper()}_STG2_TAP_COUNT           {stage2.TapCount}", file=out)
  print(f"#define {prefix.upper()}_STG2_SHR                 {stage2.Shr}", file=out)
  num_coefs = len(stage2.Coef)
  initial_count = (num_coefs//4) * 4
  print("\n", file=out)
  print(f"int32_t {prefix}_stg2_coef[{stage2.TapCount}] = {{", file=out)
  for i in range(0,initial_count,4): # print 4 coefs per row
    s = ", ".join( [hex(x) for x in stage2.Coef[i:i+4]] )
    print(s,end=',\n', file=out)

  if initial_count != num_coefs:
    print(", ".join( [hex(x) for x in stage2.Coef[initial_count:]] ), file=out)

  print("};", file=out)


if __name__ == "__main__":
  parser = header_utils.build_parser("stage2")
  args = parser.parse_args()
  print(f"stage2.py: coef_pkl_file = {args.coef_pkl_file}, file_prefix = {args.file_prefix}")

  args = parser.parse_args()
  if args.file_prefix:
    out_path = Path(args.file_dir) / f"{args.file_prefix}.h"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
      header_utils.print_header(args, [sys.stdout, f])
      main(args.coef_pkl_file, prefix=args.file_prefix, outstreams=[sys.stdout, f])
      header_utils.print_footer([sys.stdout, f])
  else:
    main(args.coef_pkl_file, outstreams=[sys.stdout])
