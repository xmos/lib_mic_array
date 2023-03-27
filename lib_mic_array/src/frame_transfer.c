// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xcore/channel.h>
#include <xcore/channel_transaction.h>
#include <stdio.h>

#include "mic_array/frame_transfer.h"


void ma_frame_tx(
    const chanend_t c_frame_out,
    const int32_t frame[],
    const unsigned channel_count,
    const unsigned sample_count)
{
  transacting_chanend_t ct_frame = chan_init_transaction_master(c_frame_out);
  t_chan_out_buf_word(&ct_frame, 
                      (uint32_t*) frame, 
                      channel_count * sample_count);
  chan_complete_transaction(ct_frame);
}




void ma_frame_rx(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count)
{
  transacting_chanend_t ct_frame = chan_init_transaction_slave(c_frame_in);
  t_chan_in_buf_word(&ct_frame, 
                     (uint32_t*) frame, 
                     channel_count * sample_count);
  chan_complete_transaction(ct_frame);
}


void ma_frame_rx_transpose(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count)
{
  transacting_chanend_t ct_frame = chan_init_transaction_slave(c_frame_in);
  for(int ch = 0; ch < channel_count; ch++){
    for(int smp = 0; smp < sample_count; smp++){
      frame[smp*channel_count+ch] = t_chan_in_word(&ct_frame);
    }
  }
  chan_complete_transaction(ct_frame);
}
