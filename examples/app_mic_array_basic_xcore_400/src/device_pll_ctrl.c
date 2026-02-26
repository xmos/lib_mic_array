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

typedef enum { BYPASS = 1, NO_BYPASS = 0 } bypass_t;
typedef enum { RESET = 1, NO_RESET = 0 } reset_t;
typedef enum { LOCK = 0, NO_LOCK = 1 } pll_lock_t;
typedef enum { ENABLED = 1, DISABLED = 0 } enable_t;
typedef enum { RCOSC = 1, XTAL = 0 } refclk_t;

static
void secondary_pll_compute_freq(
    float *out_freq,
    const float in_freq,
    const unsigned in_div,
    const unsigned fb_mult,
    const unsigned out_div)
{
    // Check ranges
    assert(in_div < 64);
    assert(out_div < 8);
    assert(fb_mult < 8192);
    
    // Calculate VCO frequency
    float f_out = in_freq;
    f_out *= (1.0f / (in_div + 1)); // Divider
    f_out *= ((fb_mult + 1) / 2.0f); // Multiplier
    f_out *= (1.0f / (out_div + 1)); // Output divider
    f_out /= 2.0f; // MIPI always halves frecuency
    out_freq[0] = f_out;
}

static
void secondary_pll_configure_freq(
    unsigned in_div,   //  input divider value
    unsigned fb_div,   //  feedback divider value
    unsigned out_div,  //  output divider value
    reset_t       reset,    //  reset after frequency change
    pll_lock_t    lock,     //  cut the clock until PLL locked
    bypass_t      bypass,   //  go into bypass mode
    enable_t      enable    //  Enable the PLL
) {
    xsystem_tile_id_t tileid = get_local_tile_id();
    xsystem_success_t val = 0;
    unsigned ctrl_val = 0;
    unsigned reset_val = 0;

    // set control
    ctrl_val = (in_div << XS1_SS_PLL_CTL_INPUT_DIVISOR_SHIFT) |
        (fb_div << XS1_SS_PLL_CTL_FEEDBACK_MUL_SHIFT) |
        (out_div << XS1_SS_PLL_CTL_POST_DIVISOR_SHIFT) |
        (lock << XS1_SS_PLL_CTL_NLOCK_SHIFT) |
        (bypass << XS1_PLL1_BYPASS_SHIFT) |
        (!enable << XS1_SS_PLL_CTL_DISABLE_SHIFT);

    
    val = sswitch_reg_try_write(tileid, XS1_SSB_CSR_PLL1_CTRL_NUM, 0);
    val = sswitch_reg_try_write(tileid, XS1_SSB_CSR_PLL1_CTRL_NUM, ctrl_val);
    assert(val);

    // set reset
    reset_val = (reset << XS1_SS_PLL_CTL_NRESET_SHIFT);
    val = sswitch_reg_try_write(tileid, XS1_SSB_CSR_SOFT_RESET_CTRL_NUM, reset_val);
    assert(val);
}

static
void configure_secondary_pll_200MHz(){
    float in_freq = 24.0;   // XTAL frequency
    float in_div  = 3.0;    // Input divisor
    float fb_mult = 300.0;  // Feedback multiplier
    float out_div = 2.0;    // Output divisor
    float out_freq = 0.0;
    secondary_pll_compute_freq(&out_freq, in_freq, in_div, fb_mult, out_div);
    printf("Configuring secondary PLL for %.2f MHz\n", out_freq);
    secondary_pll_configure_freq(in_div, fb_mult, out_div, NO_RESET, LOCK, NO_BYPASS, ENABLED);
}

static
void configure_secondary_pll_24576000_Hz(){
    float in_freq = 24.0;  // XTAL frequency
    float in_div  = -1;    // TODO
    float fb_mult = -1;    // TODO
    float out_div = -1;    // TODO
    float out_freq = 0;    // RETURN VALUE
    secondary_pll_compute_freq(&out_freq, in_freq, in_div, fb_mult, out_div);
    printf("Configuring secondary PLL for %.2f MHz\n", out_freq);
    secondary_pll_configure_freq(in_div, fb_mult, out_div, NO_RESET, LOCK, NO_BYPASS, ENABLED);
}

// -----------------------------------------

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
    configure_secondary_pll_24576000_Hz();

    assert(ret);
}
