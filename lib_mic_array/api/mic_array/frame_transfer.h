#pragma once

#include "api.h"
#include "etc/xcore_compat.h"

#include <stdint.h>

C_API_START

/**
 * @brief Transmit 32-bit PCM frame over a channel.
 * 
 * This function transmits the 32-bit PCM frame `frame[]` over the channel 
 * `c_frame_out`.
 * 
 * This is a blocking call which will wait for a receiver to call 
 * `ma_frame_rx()` (with the same channel), send the frame, and then return.
 * 
 * The receiver is not required to be on the same tile as the sender.
 * 
 * Internally, a channel transaction is established to reduce the overhead of
 * channel communication.
 * 
 * @warning No protocol is used to ensure that the shape of the frame expected
 *          by the receiver is the same as the shape being transmitted. It is
 *          the responsibility of the application developer to ensure 
 *          consistency between transmitter and receiver.
 * 
 * @param c_frame_out   Channel over which to send frame.
 * @param frame         Frame to be transmitted.
 * @param channel_count Number of channels represented in the frame.
 * @param sample_count  Number of samples represented in the frame.
 */
MA_C_API
void ma_frame_tx(
    const chanend_t c_frame_out,
    const int32_t frame[],
    const unsigned channel_count,
    const unsigned sample_count);


/**
 * @brief Receive 32-bit PCM frame over channel.
 * 
 * This function receives a PCM frame over `c_frame_in` using `ma_frame_tx()` 
 * and stores it as a 32-bit PCM frame in the buffer `frame[]`.
 * 
 * This is a blocking call which does not return until the frame has been 
 * received.
 * 
 * The sender is not required to be on the same tile as the receiver.
 * 
 * Internally, a channel transaction is established to reduce the overhead of
 * channel communication.
 * 
 * @warning No protocol is used to ensure that the shape of the frame expected
 *          by the receiver is the same as the shape being transmitted. It is
 *          the responsibility of the application developer to ensure 
 *          consistency between transmitter and receiver.
 * 
 * @param frame         Buffer to store received frame.
 * @param c_frame_in    Channel from which to receive frame.
 * @param channel_count Number of channels represented in the frame.
 * @param sample_count  Number of samples represented in the frame.
 */
MA_C_API
void ma_frame_rx(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count);


C_API_END