// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#include "api.h"
#include "etc/xcore_compat.h"

#include <stdint.h>

/**
 * @defgroup frame_transfer_h_ frame_transfer.h
 */

C_API_START

/**
 * @brief Transmit 32-bit PCM frame over a channel.
 * 
 * This function transmits the 32-bit PCM frame `frame[]` over the channel 
 * `c_frame_out`.
 * 
 * This is a blocking call which will wait for a receiver to accept the data 
 * from the channel. Typically this will be accomplished with a call to 
 * `ma_frame_rx()` or `ma_frame_rx_transpose()`.
 * 
 * The receiver is not required to be on the same tile as the sender.
 * 
 * @note Internally, a channel transaction is established to reduce the overhead 
 *       of channel communication.  Any custom functions are used to receive 
 *       this frame in an application, they must wrap the channel reads in a 
 *       (slave) channel transaction. See `xcore/channel_transaction.h`.
 * 
 * @warning No protocol is used to ensure consistency between the frame layout
 *          of the transmitter and receiver. Disagreement about frame size will
 *          likely cause one side to block indefinitely. It is the 
 *          responsibility of the application author to ensure consistency 
 *          between transmitter and receiver.
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
 * @brief Receive 32-bit PCM frame over a channel.
 * 
 * This function receives a PCM frame over `c_frame_in`. Normally, the frame 
 * will have been transmitted using `ma_frame_tx()`. The received frame is 
 * stored in `frame[]`.
 * 
 * This is a blocking call which does not return until the frame has been fully
 * received.
 * 
 * The sender is not required to be on the same tile as the receiver.
 * 
 * @note Internally, a channel transaction is established to reduce the overhead 
 *       of channel communication. This function may only be used to receive the
 *       frame if the transmitter has wrapped the channel writes in a (master)
 *       channel transaction. See `xcore/channel_transaction.h`.
 * 
 * @warning No protocol is used to ensure consistency between the frame layout
 *          of the transmitter and receiver. Disagreement about frame size will
 *          likely cause one side to block indefinitely. It is the 
 *          responsibility of the application author to ensure consistency 
 *          between transmitter and receiver.
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

    
/**
 * @brief Receive 32-bit PCM frame over a channel with transposed dimensions.
 * 
 * This function receives a PCM frame over `c_frame_in`. Normally, the frame 
 * will have been transmitted using `ma_frame_tx()`. The received frame is 
 * stored in `frame[]`.
 * 
 * Unlike `ma_frame_rx()`, this function reorders the frame elements as they are
 * received. `ma_frame_tx()` always transmits the frame elements in memory 
 * order. This function swaps the channel and sample axes so that if the 
 * transmitter frame has shape `(CHANNEL, SAMPLE)`, the caller's frame array 
 * will have shape `(SAMPLE, CHANNEL)`.
 * 
 * This is a blocking call which does not return until the frame has been fully
 * received.
 * 
 * The sender is not required to be on the same tile as the receiver.
 * 
 * @note Internally, a channel transaction is established to reduce the overhead 
 *       of channel communication. This function may only be used to receive the
 *       frame if the transmitter has wrapped the channel writes in a (master)
 *       channel transaction. See `xcore/channel_transaction.h`.
 * 
 * @warning No protocol is used to ensure consistency between the frame layout
 *          of the transmitter and receiver. Disagreement about frame size will
 *          likely cause one side to block indefinitely. It is the 
 *          responsibility of the application author to ensure consistency 
 *          between transmitter and receiver.
 * 
 * @param frame         Buffer to store received frame.
 * @param c_frame_in    Channel from which to receive frame.
 * @param channel_count Number of channels represented in the frame.
 * @param sample_count  Number of samples represented in the frame.
 */
MA_C_API
void ma_frame_rx_transpose(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count);


C_API_END