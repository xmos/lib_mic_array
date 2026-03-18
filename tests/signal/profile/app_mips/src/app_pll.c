// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__VX4B__)

#include <stdio.h>
#include <assert.h>

#include <print.h>
#include <platform.h>
#include <vx4b_defines.h>
#include <xsystem/local_tile.h>
#include <xsystem/switch.h>
#include <xcore/hwtimer.h>

static 
void delay_1ms(){
    hwtimer_t tmr = hwtimer_alloc();
    assert(tmr != 0);
    hwtimer_delay(tmr, 100000); // 1ms with 100 MHz timer tick
    hwtimer_free(tmr);
}

void app_pll_init(void)
{
    printf("Initializing PLL\n");
    xsystem_tile_id_t tileid = get_local_tile_id();

    // [0] PLL CTL DISABLE
    uint32_t DEVICE_PLL_DISABLE = 0x00000000;
    DEVICE_PLL_DISABLE = VX_PLL1_DISABLE_SET(DEVICE_PLL_DISABLE, 0);
    
    // [1] Mux 
    uint32_t DEVICE_PLL_MUX_VAL = 0x00000000;
    DEVICE_PLL_MUX_VAL = VX_APP_CLK1_MUX_BIT_SET(DEVICE_PLL_MUX_VAL, 1);
    DEVICE_PLL_MUX_VAL = VX_APP_CLK_IN_PHASE_BIT_SET(DEVICE_PLL_MUX_VAL, 1);

    // [2] PLL CTL
    uint32_t DEVICE_PLL_CTL_VAL = 0x00000000;
    DEVICE_PLL_CTL_VAL = VX_PLL1_R_DIVIDER_SET(DEVICE_PLL_CTL_VAL, 0);      // input divider: 24 MHz ref / R=1 -> 24 MHz
    DEVICE_PLL_CTL_VAL = VX_PLL1_F_MULTIPLIER_SET(DEVICE_PLL_CTL_VAL, 101); // feedback mult: 24 MHz * (F + 1 + 2/5 = 102.4) -> 2457.60 MHz 
    DEVICE_PLL_CTL_VAL = VX_PLL1_OD_DIVIDER_SET(DEVICE_PLL_CTL_VAL, 4);     // output divider: 2457.60 MHz / (OD + 1) / 2 -> 245.76 MHz 
    DEVICE_PLL_CTL_VAL = VX_PLL1_DISABLE_SET(DEVICE_PLL_CTL_VAL, 0);        // disable PLL before configuration
    DEVICE_PLL_CTL_VAL = VX_PLL1_BYPASS_SET(DEVICE_PLL_CTL_VAL, 0);         // no bypass
    DEVICE_PLL_CTL_VAL = VX_PLL1_NLOCK_SET(DEVICE_PLL_CTL_VAL, 1);          // wait for PLL lock

    // [3] FRAC (2/5)
    uint32_t DEVICE_PLL_FRAC_NOM = 0x00000000;
    DEVICE_PLL_FRAC_NOM = VX_SS_FRAC_N_ENABLE_SET(DEVICE_PLL_FRAC_NOM, 1); // enable fractional mode
    DEVICE_PLL_FRAC_NOM = VX_SS_FRAC_N_PERIOD_CYC_CNT_SET(DEVICE_PLL_FRAC_NOM, 4); // +1 -> 5
    DEVICE_PLL_FRAC_NOM = VX_SS_FRAC_N_F_HIGH_CYC_CNT_SET(DEVICE_PLL_FRAC_NOM, 1); // +1 -> 2

    // [4] APP DIVIDER
    uint32_t DEVICE_PLL_DIV_0 = 0x00000000;
    DEVICE_PLL_DIV_0 = VX_APP_CLK_DIV_ENABLE_SET(DEVICE_PLL_DIV_0, 1); // enable app clock divider
    DEVICE_PLL_DIV_0 = VX_APP_CLK_DIV_VALUE_SET(DEVICE_PLL_DIV_0, 4); // set divider to 4 -> 245.76 MHz / (4 + 1)  / 2 -> 24.576 MHz
    
    // print reg values
    printf("PLL Configuration:\n");
    printf("PLL DISABLE: 0x%08lX\n", DEVICE_PLL_DISABLE);
    printf("PLL MUX VAL: 0x%08lX\n", DEVICE_PLL_MUX_VAL);
    printf("PLL CTL VAL: 0x%08lX\n", DEVICE_PLL_CTL_VAL);
    printf("PLL DIV VAL: 0x%08lX\n", DEVICE_PLL_DIV_0);
    printf("PLL FRAC_NOM: 0x%08lX\n", DEVICE_PLL_FRAC_NOM);

    // CONFIGURE
    sswitch_reg_try_write(tileid, VX_SSB_CSR_PLL1_CTRL_NUM, DEVICE_PLL_DISABLE);            // disable PLL before configuration
    sswitch_reg_try_write(tileid, VX_SSB_CSR_CLK_SWITCH_CTRL_NUM, DEVICE_PLL_MUX_VAL);      // switch app clock to PLL1 output
    sswitch_reg_try_write(tileid, VX_SSB_CSR_PLL1_CTRL_NUM, DEVICE_PLL_CTL_VAL);            // configure PLL control register
    sswitch_reg_try_write(tileid, VX_SSB_CSR_PLL1_FRACN_CTRL_NUM, DEVICE_PLL_FRAC_NOM);     // configure PLL fractional control register
    sswitch_reg_try_write(tileid, VX_SSB_CSR_APP_CLK1_DIV_NUM, DEVICE_PLL_DIV_0);           // configure app clock divider
    delay_1ms();
}

#elif defined(__XS3A__)

#include <platform.h>
#include <xs1.h>
#include <xcore/hwtimer.h>
#include <xcore/assert.h>

#define DEVICE_PLL_CTL_VAL   0x0A019803 // Valid for all fractional values
#define DEVICE_PLL_FRAC_NOM  0x800095F9 // 24.576000 MHz

void app_pll_init(void)
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

    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_CTL_NUM, DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM, DEVICE_PLL_FRAC_NOM);
    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM, DEVICE_PLL_DIV_0);
}

#endif // defined(__VX4B__)
