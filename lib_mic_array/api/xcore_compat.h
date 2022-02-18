#pragma once

/**
 * There is a compiler error on Windows if trying to #include some of the xcore libs from a .XC file,
 * but the definitions are still needed. This is a workaround.
 */

#ifdef __XC__

extern "C" {

typedef unsigned xclock_t;
typedef unsigned port_t;
typedef unsigned chanend_t;

typedef struct {
  unsigned end_a;
  unsigned end_b;
 } streaming_channel_t;

#else //__XC__

#include <xs1_user.h>
#include <xcore/channel_streaming.h>
#include <xcore/clock.h>
#include <xcore/port.h>

#endif //__XC__


#ifdef __XC__
}
#endif //__XC__