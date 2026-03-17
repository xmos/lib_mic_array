// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>

#include <xs1.h>
#include <platform.h>

extern "C"{
  int main_tile_0(chanend c_audio_frames);
  int main_tile_1(chanend c_audio_frames);
}

int main() {
  chan c_audio_frames;
  par {
    on tile[0]: main_tile_0(c_audio_frames);
    on tile[1]: main_tile_1(c_audio_frames);
  }
  return 0;
}
