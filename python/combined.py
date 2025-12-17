# Copyright 2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import sys
from pathlib import Path
import stage1
import stage2
import header_utils

"""
Generate a single C header that combines stage-1 and stage-2 filter outputs.

This script loads a pickled filter design and emits:
- Stage-1 macros/arrays (from stage1.py)
- Stage-2 macros/arrays (from stage2.py)

Usage:
  python combined.py <coef_pkl_file> -fp <prefix> [-fd <out_dir>]

If -fp is provided, the header <out_dir>/<prefix>.h is written and also echoed
to stdout. If -fp is omitted, content is printed to stdout only.

Refer to python/README.rst for more details.
"""

if __name__ == "__main__":
  parser = header_utils.build_parser("combined")
  args = parser.parse_args()
  print(f"combined.py: coef_pkl_file = {args.coef_pkl_file}, file_prefix = {args.file_prefix}")

  if args.file_prefix:
    out_path = Path(args.file_dir) / f"{args.file_prefix}.h"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
      header_utils.print_header(args, [sys.stdout, f])
      stage1.main(args.coef_pkl_file, prefix=args.file_prefix, outstreams=[sys.stdout, f])
      num_fir_stages = stage2.main(args.coef_pkl_file, prefix=args.file_prefix, outstreams=[sys.stdout, f])
      header_utils.print_footer([sys.stdout, f], num_filter_stages=num_fir_stages+1)
  else:
    stage1.main(args.coef_pkl_file, outstreams=[sys.stdout])
    num_fir_stages = stage2.main(args.coef_pkl_file, outstreams=[sys.stdout])
