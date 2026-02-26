// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <assert.h>

#include <print.h>
#include <platform.h>
#include <vx4b_defines.h>
#include <xsystem/local_tile.h>
#include <xsystem/switch.h>
#include <xcore/hwtimer.h>

#include "device_pll_ctrl.h"

static 
void delay_1ms(){
    hwtimer_t tmr = hwtimer_alloc();
    assert(tmr != 0);
    hwtimer_delay(tmr, 100000); // 1ms with 100 MHz timer tick
    hwtimer_free(tmr);
}

void device_pll_init(void)
{
    xsystem_success_t ret = 1;
    xsystem_tile_id_t tileid = get_local_tile_id();

    uint32_t regaddr = 0x00000000;
    uint32_t wdata = 0x00000000;
    const unsigned DEVICE_PLL_DIV_0 = 0x80000004;
    
    // disable PLL1
    regaddr = XS1_SSB_CSR_PLL1_CTRL_NUM;
    wdata = XS1_SS_PLL_CTL_DISABLE_SET(wdata, 1);
    ret |= sswitch_reg_try_write(tileid, regaddr, wdata);
    
    // delay 1ms
    delay_1ms();

    // write PLL config
    regaddr = XS1_SSB_CSR_PLL1_CTRL_NUM;
    wdata = DEVICE_PLL_CTL_VAL;
    ret |= sswitch_reg_try_write(tileid, regaddr, wdata);

    regaddr = XS1_SSB_CSR_PLL1_FRACN_CTRL_NUM;
    wdata = DEVICE_PLL_FRAC_NOM;
    ret |= sswitch_reg_try_write(tileid, regaddr, wdata);

    regaddr = XS1_SSB_CSR_APP_CLK0_DIV_NUM;
    wdata = DEVICE_PLL_DIV_0;
    ret |= sswitch_reg_try_write(tileid, regaddr, wdata);

    assert(ret);
}
