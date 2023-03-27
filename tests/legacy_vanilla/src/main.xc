// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.


#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include "mic_array.h"
#include "mic_array_vanilla.h"

/////////////////////////////////////////////////////////////////////////////
//  WARNING: This is just a test app to make sure the library's 
//           module_build_info is correct. This app doesn't actually do 
//           anything at the moment.
/////////////////////////////////////////////////////////////////////////////

unsafe{

int main() {
  chan c_audio_frames;
  par {
    on tile[0]: {
      xscope_config_io(XSCOPE_IO_BASIC);
    }
    on tile[1]: {
      xscope_config_io(XSCOPE_IO_BASIC);
      ma_vanilla_init();
      par {  ma_vanilla_task((chanend_t) c_audio_frames);   }
    }
  }

  return 0;
}

}
