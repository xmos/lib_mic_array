// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app.h"

// Only the transitional VX4 toolchain provides <netmain.h>.
#if defined(__has_include)
#if __has_include(<netmain.h>)
#define APP_USE_NETWORK_MAIN 1
#endif
#endif

#if defined(APP_USE_NETWORK_MAIN)

#include <netmain.h>

NETWORK_MAIN(
  TILE_MAIN(app_main, 0, ())
)

#else

int main(void)
{
    app_main();
    return 0;
}

#endif
