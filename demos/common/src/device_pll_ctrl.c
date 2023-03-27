// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <platform.h>
#include <xs1.h>
#include <xcore/hwtimer.h>
#include <xcore/assert.h>
#include "device_pll_ctrl.h"


void device_pll_init(void)
{
    unsigned tileid = get_local_tile_id();

    const unsigned DEVICE_PLL_DISABLE = 0x0201FF04;
    const unsigned DEVICE_PLL_DIV_0   = 0x80000004;

    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, 
                              DEVICE_PLL_DISABLE);

    hwtimer_t tmr = hwtimer_alloc();
    {
        xassert(tmr != 0);
        hwtimer_delay(tmr, 100000); // 1ms with 100 MHz timer tick
    }
    hwtimer_free(tmr);

    write_sswitch_reg(tileid, 
                      XS1_SSWITCH_SS_APP_PLL_CTL_NUM, 
                      DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid, 
                      XS1_SSWITCH_SS_APP_PLL_CTL_NUM, 
                      DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid, 
                      XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM, 
                      DEVICE_PLL_FRAC_NOM);
    write_sswitch_reg(tileid, 
                      XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM, 
                      DEVICE_PLL_DIV_0);
}