// Copyright 2023-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>

#include <xs1.h>
#include <platform.h>

extern "C" {
  void user_mic(chanend c_mic_audio);
  void user_audio(chanend c_mic_audio);
}

int main(void)
{
  // Channel declarations
  chan c_mic_audio;

  // Initialize parallel tasks  
  par{
    on tile[1]: user_mic(c_mic_audio);                         
    on tile[1]: user_audio(c_mic_audio);             
  }
  return 0;
}
