// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined (__XS3A__)
#include <platform.h>
#include <xs1.h>
#elif defined (__VX4B__)
#include <vx4b_defines.h>
#include <xsystem/local_tile.h>
#include <xsystem/switch.h>
#endif

#include <xcore/hwtimer.h>
#include <xcore/assert.h>
#include "device_pll_ctrl.h"


void device_pll_init(void)
{
    #if 0
    unsigned tileid = get_local_tile_id();

    #if defined (__XS3A__)
    // SS_APP_PLL_BYPASS             (29:29)  = 0b0             = 0x0
    // SS_APP_PLL_INPUT_FROM_SYS_PLL (28:28)  = 0b0             = 0x0
    // SS_APP_PLL_ENABLE             (27:27)  = 0b0             = 0x0
    // Reserved                      (26:26)  = 0b0             = 0x0
    // SS_PLL_CTL_POST_DIVISOR       (25:23)  = 0b100           = 0x4
    // Reserved                      (22:21)  = 0b00            = 0x0
    // SS_PLL_CTL_FEEDBACK_MUL       (20:08)  = 0b0000111111111 = 0x01FF
    // Reserved                      (07:06)  = 0b00            = 0x0
    // SS_PLL_CTL_INPUT_DIVISOR      (05:00)  = 0b000100        = 0x04
    const unsigned DEVICE_PLL_DISABLE = 0x0201FF04;

    // SS_APP_CLK_FROM_APP_PLL       (31:31)  = 0b1                = 0x1
    // Reserved                      (30:17)  = 0b00000000000000   = 0x0
    // SS_APP_CLK_DIV_DISABLE        (16:16)  = 0b0                = 0x0
    // SS_APP_CLK_DIV                (15:00)  = 0b0000000000000100 = 0x0004
    const unsigned DEVICE_PLL_DIV_0   = 0x80000004;
    #elif defined (__VX4B__)
    // Reserved     (31:31) = 0b0             = 0x0
    // NLOCK        (30:30) = 0b0             = 0x0
    // Reserved     (29:29) = 0b0             = 0x0
    // BYPASS       (28:28) = 0b0             = 0x0
    // Reserved     (27:27) = 0b0             = 0x0
    // DISABLE      (26:26) = 0b1             = 0x1
    // OD_DIVIDER   (25:23) = 0b100           = 0x4
    // Reserved     (22:21) = 0b00            = 0x0
    // F_MULTIPLIER (20:08) = 0b0000111111111 = 0x01FF
    // Reserved     (07:06) = 0b00            = 0x0
    // R_DIVIDER    (05:00) = 0b000100        = 0x04
    const unsigned DEVICE_PLL_DISABLE = 0x0601FF04;
    const unsigned DEVICE_PLL_DIV_0   = 0x80000004;
    #else
    #error "Unsupported architecture"
    #endif

    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, 
                              DEVICE_PLL_DISABLE);

    hwtimer_t tmr = hwtimer_alloc();
    {
        xassert(tmr != 0);
        hwtimer_delay(tmr, 100000); // 1ms with 100 MHz timer tick
    }
    hwtimer_free(tmr);

    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM, DEVICE_PLL_FRAC_NOM);
    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM, DEVICE_PLL_DIV_0);
#endif
}
