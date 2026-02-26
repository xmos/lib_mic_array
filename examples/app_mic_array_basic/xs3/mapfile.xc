// Copyright 2023-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

#include <xs1.h>
#include <platform.h>

extern "C" {
  void main_tile_0();
  void main_tile_1();
}

int main(void)
{
  // Initialize parallel tasks  
  par{
    on tile[0]: main_tile_0();                         
    on tile[1]: main_tile_1();             
  }
  return 0;
}
