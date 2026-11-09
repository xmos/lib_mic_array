// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(APP_MIPS_NEW_VX4_TOOLCHAIN)

#error "app_mips is not currently supported by the new VX4 toolchain."

#elif defined(__VX4B__)

#include <stdint.h>
#include <platform.h>
#include <netmain.h>
#include <xcore/chanend.h>

extern int main_tile_0(chanend_t c_audio_frames);
extern int main_tile_1(chanend_t c_audio_frames);

DECLARE_CHAN(c)

NETWORK_MAIN(
  TILE_MAIN(main_tile_1, 1, (CHAN(c))),
  TILE_MAIN(main_tile_0, 0, (CHAN(c)))
)

#endif
