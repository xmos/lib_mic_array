// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#if defined(__riscv)

#include <stdint.h>

#include <xcore/chanend.h>
#include <xcore/channel.h>
#include <xcore/parallel.h>

extern int main_tile_0(chanend_t c_audio_frames);
extern int main_tile_1(chanend_t c_audio_frames);

static void run_tile_0(chanend_t c_audio_frames)
{
  (void) main_tile_0(c_audio_frames);
}

static void run_tile_1(chanend_t c_audio_frames)
{
  (void) main_tile_1(c_audio_frames);
}

DECLARE_JOB(run_tile_0, (chanend_t));
DECLARE_JOB(run_tile_1, (chanend_t));

int main(void)
{
  channel_t c_audio_frames = chan_alloc();
  PAR_JOBS(
    PJOB(run_tile_0, (c_audio_frames.end_a)),
    PJOB(run_tile_1, (c_audio_frames.end_b))
  );
  chan_free(c_audio_frames);
  return 0;
}

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
