// Copyright 2020-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdio.h>
#include <xscope.h>

#include "unity_fixture.h"

int main(int argc, const char* argv[])
{ 
  xscope_config_io(XSCOPE_IO_BASIC);

  UnityGetCommandLineOptions(argc, argv);
  UnityBegin(argv[0]);

  printf("\n\n");

  RUN_TEST_GROUP(dcoe_state_init);
  RUN_TEST_GROUP(dcoe_filter);
  RUN_TEST_GROUP(DcoeSampleFilter);
  
  RUN_TEST_GROUP(ma_frame_tx_rx);
  RUN_TEST_GROUP(ma_frame_tx_rx_transpose);
  RUN_TEST_GROUP(ChannelFrameTransmitter);
  RUN_TEST_GROUP(FrameOutputHandler);
  
  RUN_TEST_GROUP(deinterleave2);
  RUN_TEST_GROUP(deinterleave4);
  RUN_TEST_GROUP(deinterleave8);
  RUN_TEST_GROUP(deinterleave16);

  RUN_TEST_GROUP(deinterleave_pdm_samples);
  
  return UNITY_END();
}
