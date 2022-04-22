// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

/**
 * The `<xcore/>` headers cannot be safely included from XC files, but 
 * several of the types defined in those headers need to be available in XC. 
 * This header is a work-around which defines those types for XC but includes
 * them for C or CPP files.
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
  
  typedef struct {
    unsigned end_a;
    unsigned end_b;
  } channel_t;

}

#else //__XC__

#include <xs1_user.h>
#include <xcore/channel_streaming.h>
#include <xcore/channel.h>
#include <xcore/clock.h>
#include <xcore/port.h>

#endif //__XC__

