
#include "app_common.h"


void eat_audio_frames_task(
    chanend_t c_from_decimator,
    static const unsigned frame_words)
{
  int32_t audio_frame[frame_words];

  //make up the details of the format because it doesn't matter.
  const ma_frame_format_t format = 
        ma_frame_format(frame_words, 1, MA_FMT_SAMPLE_CHANNEL);

  while(1){
    ma_frame_rx_s32(audio_frame, c_from_decimator, &format);
  }
}

void receive_and_buffer_audio_task(
    chanend_t c_from_decimator,
    audio_ring_buffer_t* output_buffer,
    const unsigned mic_count,
    const unsigned samples_per_frame,
    static const unsigned frame_words)
{
  int32_t audio_frame[frame_words];

  // Frame MUST be in MA_FMT_SAMPLE_CHANNEL layout,
  // which is why this doesn't take a ma_frame_format_t argument
  const ma_frame_format_t format = 
        ma_frame_format(mic_count, samples_per_frame, MA_FMT_SAMPLE_CHANNEL);

  while(1){

    ma_frame_rx_s32(audio_frame, c_from_decimator, &format);

    for(int k = 0; k < frame_words; k++)
      audio_frame[k] <<= 8;

    for(int k = 0; k < samples_per_frame; k++)
      abuff_frame_add( output_buffer, &audio_frame[k * mic_count] );
  }
}