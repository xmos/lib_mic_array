// Copyright (c) 2022-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public License: Version 1

#include <assert.h>

#include "app_config.h"
#include "i2c.h"
#include "aic3204/aic3204.h"

i2c_master_t i2c_master_ctx;

#ifndef PORT_CODEC_RST_N
#define PORT_CODEC_RST_N XS1_PORT_4A
#endif

void aic3204_board_init(void)
{
  i2c_master_init(&i2c_master_ctx,
                  PORT_I2C_SCL, 0, 0,
                  PORT_I2C_SDA, 0, 0,
                  100);

  int res = 0;
  res = aic3204_init();
  assert( res == 0 );
}

int aic3204_reg_write(uint8_t reg, uint8_t val)
{
    i2c_regop_res_t ret;

    ret = write_reg(&i2c_master_ctx, AIC3204_I2C_DEVICE_ADDR, reg, val);

    if (ret == I2C_REGOP_SUCCESS) {
        return 0;
    } else {
        return -1;
    }
}

void aic3204_codec_reset(void)
{
    const port_t codec_rst_port = PORT_CODEC_RST_N;
    port_enable(codec_rst_port);
    port_out(codec_rst_port, 0xF);
}

void aic3204_wait(uint32_t wait_ms)
{
    delay_milliseconds(wait_ms);
}
