
#include <platform.h>

#include "app_config.h"
#include "app.h"
#include "i2s.h"
#include "util/audio_buffer.h"
#include "mic_array/framing.h"
#include "mic_array/etc/filters_default.h"

#include <xcore/interrupt.h>

#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <math.h>


// including <xcore/channel_streaming.h> is not supported in XC files
streaming_channel_t app_s_chan_alloc()
{
  return s_chan_alloc();
}

// including <xcore/channel_streaming.h> is not supported in XC files
channel_t app_chan_alloc()
{
  return chan_alloc();
}