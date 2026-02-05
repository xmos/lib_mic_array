// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xcore/channel.h>
#include <xcore/channel_transaction.h>
#include <stdio.h>

#include "mic_array/frame_transfer.h"
#include "mic_array/shutdown.h" // ma_shutdown() follows the same channel transfer protocol as other ma_frame transfer functions
                                // (without the actual data transfer), hence defining here for ease of maintenance


unsigned ma_frame_tx(
    const chanend_t c_frame_out,
    const int32_t frame[],
    const unsigned channel_count,
    const unsigned sample_count)
{
  unsigned shutdown = 0;
  chanend_out_control_token(c_frame_out, XS1_CT_END);
  shutdown = chanend_test_control_token_next_byte(c_frame_out);
  if(shutdown)
  {
    chanend_check_control_token(c_frame_out, XS1_CT_END);
    // For shutdown, MicArray thread closes channel only after shutdown is complete
  }
  else {
    int dummy = chanend_in_byte(c_frame_out);
    (void)dummy;
    for(int i=0; i<channel_count*sample_count; i++) {
      chanend_out_word(c_frame_out, frame[i]);
    }
    chanend_out_control_token(c_frame_out, XS1_CT_END); // close the channel only when not shutting down
    chanend_check_control_token(c_frame_out, XS1_CT_END);
  }
  return shutdown;
}

void ma_frame_rx(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count)
{
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_byte(c_frame_in, 0); //dummy indicating wish to proceed with data transfer
  for(int i=0; i<channel_count*sample_count; i++) {
    frame[i] = chanend_in_word(c_frame_in);
  }
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END);
}


void ma_frame_rx_transpose(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count)
{
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_byte(c_frame_in, 0); //dummy indicating wish to proceed with data transfer

  for(int ch = 0; ch < channel_count; ch++){
    for(int smp = 0; smp < sample_count; smp++){
      frame[smp*channel_count+ch] = chanend_in_word(c_frame_in);
    }
  }
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END);
}

void ma_shutdown(const chanend_t c_frame_in) //same chanend as the one used in ma_frame_rx()
{
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END); // indicate shutdown to ma_frame_tx()
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END);
}
