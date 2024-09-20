// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <platform.h>
#include <stdlib.h>
#include <assert.h>

#include "i2c.h"
#include "i2s.h"

#include "dac3101/dac3101.h"

#define PDM_CLKBLK_1  XS1_CLKBLK_1
#define PDM_CLKBLK_2  XS1_CLKBLK_2

i2c_master_t i2c_context;



void board_dac3101_init()
{
  int res = 0;
  
  i2c_master_init(&i2c_context,
                  PORT_I2C_SCL, 0, 0,
                  PORT_I2C_SDA, 0, 0,
                  100);
  assert( res == 0 );

  
  res = dac3101_init(&i2c_context);
  assert( res == 0 );


}

