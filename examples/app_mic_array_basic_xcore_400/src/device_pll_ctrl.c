// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>
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

/*
 * PLL1 Control Register Fields:
 *
 * PLL1_R_DIVIDER      - Input divisor value.
 * PLL1_F_MULTIPLIER   - Feedback multiplier value.
 * PLL1_OD_DIVIDER     - Output divider value.
 * PLL1_DISABLE        - Disable the PLL when this is 1.
 * PLL1_BYPASS         - When set to 1 the PLL will be bypassed.
 * PLL1_NLOCK          - If set to 1 the chip will not wait for the PLL to relock.
 */

void device_pll_init(void)
{
    printf("Initializing PLL\n");
    xsystem_tile_id_t tileid = get_local_tile_id();

    // PLL CTL
    uint32_t DEVICE_PLL_CTL_VAL = 0x00000000;
    DEVICE_PLL_CTL_VAL = VX_PLL1_R_DIVIDER_SET(DEVICE_PLL_CTL_VAL, 0); // input divider = 1, 24 -> 24 MHz
    DEVICE_PLL_CTL_VAL = VX_PLL1_F_MULTIPLIER_SET(DEVICE_PLL_CTL_VAL, 101); // feedback multiplier 
    DEVICE_PLL_CTL_VAL = VX_PLL1_OD_DIVIDER_SET(DEVICE_PLL_CTL_VAL, 4); // output divider 
    DEVICE_PLL_CTL_VAL = VX_PLL1_DISABLE_SET(DEVICE_PLL_CTL_VAL, 0); // disable PLL
    DEVICE_PLL_CTL_VAL = VX_PLL1_BYPASS_SET(DEVICE_PLL_CTL_VAL, 0); // no bypass
    DEVICE_PLL_CTL_VAL = VX_PLL1_NLOCK_SET(DEVICE_PLL_CTL_VAL, 0); // wait for PLL lock

    // APP DIVIDER
    uint32_t DEVICE_PLL_DIV_0 = 0x00000000;
    DEVICE_PLL_DIV_0 = VX_APP_CLK_DIV_ENABLE_SET(DEVICE_PLL_DIV_0, 1);
    DEVICE_PLL_DIV_0 = VX_APP_CLK_DIV_VALUE_SET(DEVICE_PLL_DIV_0, 4);

    // FRAC
    uint32_t DEVICE_PLL_FRAC_NOM = 0x80000104;
    
    // print reg values
    printf("PLL CTL VAL: 0x%08lX\n", DEVICE_PLL_CTL_VAL);
    printf("PLL DIV VAL: 0x%08lX\n", DEVICE_PLL_DIV_0);
    printf("PLL FRAC_NOM: 0x%08lX\n", DEVICE_PLL_FRAC_NOM);

    // CONFIGURE
    sswitch_reg_try_write(tileid, VX_SSB_CSR_PLL1_CTRL_NUM, DEVICE_PLL_CTL_VAL);
    sswitch_reg_try_write(tileid, VX_SSB_CSR_PLL1_FRACN_CTRL_NUM, DEVICE_PLL_FRAC_NOM);
    sswitch_reg_try_write(tileid, VX_SSB_CSR_APP_CLK1_DIV_NUM, DEVICE_PLL_DIV_0);
}
