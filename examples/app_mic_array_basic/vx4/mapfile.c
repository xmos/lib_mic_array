// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <netmain.h>

extern void main_tile_0();
extern void main_tile_1();

NETWORK_MAIN(
  TILE_MAIN(main_tile_1, 1, ()),
  TILE_MAIN(main_tile_0, 0, ())
)
