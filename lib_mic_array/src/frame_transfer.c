
#include "mic_array/frame_transfer.h"


#include <xcore/channel.h>
#include <xcore/channel_transaction.h>
#include <assert.h>


enum {
  CODE_SEND_DATA = 1,
  CODE_SEND_PTR  = 2,
};


static inline
void ma_frame_tx_s32_send_data(
    transacting_chanend_t* ct_frame,
    const int32_t frame[],
    const ma_frame_format_t* format)
{
  const unsigned frame_words = format->sample_count * format->channel_count;

  // Send the layout (it will be the receiver's responsibility to
  //                  reorganize if necessary)
  t_chan_out_word(ct_frame, format->layout);

  // Send the data
  for(int k = 0; k < frame_words; k++)
    t_chan_out_word(ct_frame, (uint32_t) frame[k]);
}


void ma_frame_tx_s32(
    const chanend_t c_frame_out,
    const int32_t frame[],
    const ma_frame_format_t* format)
{
  // @todo for now only support (channel, sample) on tx
  assert( format->layout == MA_FMT_CHANNEL_SAMPLE );

  transacting_chanend_t ct_frame = chan_init_transaction_master(c_frame_out);

  switch(t_chan_in_word(&ct_frame)){

    case CODE_SEND_DATA:
      ma_frame_tx_s32_send_data(&ct_frame, frame, format);
      break;

    case CODE_SEND_PTR:
      t_chan_out_word(&ct_frame,  (uint32_t) &frame[0]);
      break;

    default:
      assert(0);
  }

  chan_complete_transaction(ct_frame);
}





void ma_frame_tx_s16(
    const chanend_t c_frame_out,
    const int16_t frame[],
    const ma_frame_format_t* format)
{
  const unsigned frame_elms = format->sample_count * format->channel_count;

  transacting_chanend_t ct_frame = chan_init_transaction_master(c_frame_out);

  switch(t_chan_in_word(&ct_frame)){

    case CODE_SEND_DATA:
      // Send the layout (it will be the receiver's responsibility to
      //                  reorganize if necessary)
      t_chan_out_word(&ct_frame, format->layout);

      // Send the data
      for(int k = 0; k < frame_elms; k++)
        t_chan_out_word(&ct_frame, frame[k]);
      
      break;

    case CODE_SEND_PTR:
      t_chan_out_word(&ct_frame,  (uint32_t) &frame[0]);
      break;

    default:
      assert(0);
  }

  chan_complete_transaction(ct_frame);
}


void ma_frame_rx_s32(
    int32_t frame[],
    const chanend_t c_frame_in,
    const ma_frame_format_t* format)
{

  transacting_chanend_t ct_frame = chan_init_transaction_slave(c_frame_in);

  t_chan_out_word(&ct_frame, CODE_SEND_DATA);

  // We expect the layout followed by the frame data.
  ma_frame_layout_e tx_layout = t_chan_in_word(&ct_frame);

  if(tx_layout == format->layout){
    const unsigned frame_words = format->sample_count * format->channel_count;

    t_chan_in_buf_word(&ct_frame, (uint32_t*) frame, frame_words);

  } else {
    const unsigned lim1 = (tx_layout == MA_FMT_CHANNEL_SAMPLE)? 
                          format->channel_count : format->sample_count;

    const unsigned lim2 = (tx_layout == MA_FMT_CHANNEL_SAMPLE)? 
                          format->sample_count : format->channel_count;

    // if (tx_layout == MA_FMT_CHANNEL_SAMPLE) then k1 --> channel and k2 --> sample 
    for(int k1 = 0; k1 < lim1; k1++){
      for(int k2 = 0; k2 < lim2; k2++){
        frame[lim1 * k2 + k1] = t_chan_in_word(&ct_frame);
      }
    }
  }

  chan_complete_transaction(ct_frame);
}


void ma_frame_rx_s16(
    int16_t frame[],
    const chanend_t c_frame_in,
    const ma_frame_format_t* format,
    const right_shift_t sample_shr)
{

  transacting_chanend_t ct_frame = chan_init_transaction_slave(c_frame_in);

  t_chan_out_word(&ct_frame, CODE_SEND_DATA);

  // We expect the layout followed by the frame data.
  ma_frame_layout_e tx_layout = t_chan_in_word(&ct_frame);

  if(tx_layout == format->layout){
    const unsigned frame_elms = format->sample_count * format->channel_count;

    for(int k = 0; k < frame_elms; k++)
      frame[k] = t_chan_in_word(&ct_frame) >> sample_shr;
  } else {
    const unsigned lim1 = (tx_layout == MA_FMT_CHANNEL_SAMPLE)? 
                          format->channel_count : format->sample_count;

    const unsigned lim2 = (tx_layout == MA_FMT_CHANNEL_SAMPLE)? 
                          format->sample_count : format->channel_count;

    // if (tx_layout == MA_FMT_CHANNEL_SAMPLE) then k1 --> channel and k2 --> sample 
    for(int k1 = 0; k1 < lim1; k1++){
      for(int k2 = 0; k2 < lim2; k2++){
        frame[lim1 * k2 + k1] = t_chan_in_word(&ct_frame) >> sample_shr;
      }
    }
  }

  chan_complete_transaction(ct_frame);
}


int32_t* ma_frame_rx_ptr(
    const chanend_t c_frame_in)
{
  transacting_chanend_t ct_frame = chan_init_transaction_slave(c_frame_in);

  t_chan_out_word(&ct_frame, CODE_SEND_PTR);

  return (int32_t*) t_chan_in_word(&ct_frame);

  chan_complete_transaction(ct_frame);
}