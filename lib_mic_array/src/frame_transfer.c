
#include "mic_array/frame_transfer.h"

#include <xcore/channel.h>
#include <xcore/channel_transaction.h>

#include <stdio.h>

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