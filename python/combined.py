# Copyright 2025 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import argparse
import sys
import stage1
import stage2
from pathlib import Path
from header_utils import *

if __name__ == "__main__":
  parser = build_parser("combined")
  args = parser.parse_args()
  print(f"combined.py: coef_pkl_file = {args.coef_pkl_file}, file_prefix = {args.file_prefix}")

  if args.file_prefix:
    out_path = Path(args.file_dir) / f"{args.file_prefix}.h"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
      print_header(args, [sys.stdout, f])
      stage1.main(args.coef_pkl_file, prefix=args.file_prefix, outstreams=[sys.stdout, f])
      stage2.main(args.coef_pkl_file, prefix=args.file_prefix, outstreams=[sys.stdout, f])
      print_footer([sys.stdout, f])
  else:
    stage1.main(args.coef_pkl_file, outstreams=[sys.stdout])
    stage2.main(args.coef_pkl_file, outstreams=[sys.stdout])
