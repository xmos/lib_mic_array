// Copyright 2025-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <xs1.h>
#include <platform.h>

#include "app.h"

int main()
{
  par {
    on tile[0]: main_tile_0();
    on tile[1]: main_tile_1();
  }
  return 0;
}
