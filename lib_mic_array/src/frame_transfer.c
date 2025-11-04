// Copyright 2022-2025 XMOS LIMITED.
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
#if 0
  transacting_chanend_t ct_frame = chan_init_transaction_master(c_frame_out);
  t_chan_out_buf_word(&ct_frame,
                      (uint32_t*) frame,
                      channel_count * sample_count);
  chan_complete_transaction(ct_frame);
#else
  chanend_out_control_token(c_frame_out, XS1_CT_END);
  //asm volatile("testct %0, res[%1]" : "=r"(shutdown) : "r"(c_frame_out));
  shutdown = chanend_test_control_token_next_byte(c_frame_out);
  if(shutdown)
  {
    chanend_check_control_token(c_frame_out, XS1_CT_END);
  }
  else {
    int dummy = chanend_in_byte(c_frame_out);
    (void)dummy;
    for(int i=0; i<channel_count*sample_count; i++) {
      chanend_out_word(c_frame_out, frame[i]);
    }
  }
  chanend_out_control_token(c_frame_out, XS1_CT_END); // close the channel for irrespective of shutdown or not
  chanend_check_control_token(c_frame_out, XS1_CT_END);
#endif
  return shutdown;
}

void ma_frame_rx(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count)
{
#if 0
  transacting_chanend_t ct_frame = chan_init_transaction_slave(c_frame_in);
  t_chan_in_buf_word(&ct_frame,
                     (uint32_t*) frame,
                     channel_count * sample_count);
  chan_complete_transaction(ct_frame);
#else
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_byte(c_frame_in, 0); //dummy indicating wish to proceed with data transfer
  for(int i=0; i<channel_count*sample_count; i++) {
    frame[i] = chanend_in_word(c_frame_in);
  }
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END);

#endif
}


void ma_frame_rx_transpose(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count)
{
#if 0
  transacting_chanend_t ct_frame = chan_init_transaction_slave(c_frame_in);
  for(int ch = 0; ch < channel_count; ch++){
    for(int smp = 0; smp < sample_count; smp++){
      frame[smp*channel_count+ch] = t_chan_in_word(&ct_frame);
    }
  }
  chan_complete_transaction(ct_frame);
#else
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_byte(c_frame_in, 0); //dummy indicating wish to proceed with data transfer

  for(int ch = 0; ch < channel_count; ch++){
    for(int smp = 0; smp < sample_count; smp++){
      frame[smp*channel_count+ch] = chanend_in_word(c_frame_in);
    }
  }
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END);
#endif
}

void ma_shutdown(const chanend_t c_frame_in) //same chanend as whats used in ma_frame_rx()
{
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END); // indicate shutdown to ma_frame_tx()
  chanend_check_control_token(c_frame_in, XS1_CT_END);
  chanend_out_control_token(c_frame_in, XS1_CT_END);
}
