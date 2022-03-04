#pragma once

#include "api.h"
#include "etc/xcore_compat.h"

#include <stdint.h>

C_API_START

/**
 * @brief Frame Transfer
 * 
 * This module contains functions for sending and receiving audio frames over
 * channels.
 * 
 * @par Blocking Calls
 * 
 * All functions are blocking. The transmit functions (`tx`) and receive
 * functions (`rx`) will wait until the transfer is complete before returning.
 * 
 * @par Managed Protocol
 * 
 * The transfer protocol is managed and intended to be opaque to users, so
 * frames should be received using one of these functions if and only if the
 * frame is being sent using one of these functions.
 * 
 * Note, however, that the transmitter and receiver do _not_ communicate the
 * size (channel count, sample count) of the frame to one another. It is the
 * responsibility of the user to ensure these are consistent between transmitter
 * and receiver.
 * 
 * @par Bit-depth Conversion
 * 
 * All sample data is transferred over channels as 32-bit words, including
 * for the 16-bit (`s16`) functions. This allows sample depth conversion
 * in-flight between threads.
 * 
 * @par Layout Conversion
 * 
 * For frames, the `ma_frame_format_t` structs supplied to the calls indicate 
 * the memory layout of the frame being transmitted or to be received. The 
 * layout is negotiated between transmitter and receiver, allowing for memory
 * layout conversion in-flight between threads.
 * 
 */

/**
 * @brief Transmit 32-bit PCM frame over channel.
 * 
 * This function transmits the 32-bit PCM frame `frame[]` over the channel 
 * `c_frame_out`.
 * 
 * This is a blocking call which will wait for a receiver to call a 
 * corresponding receive (`rx`) function, send the frame, and then return.
 * 
 * Where the transmitter is very time-sensitive (such as in the decimator
 * thread), it is highly recommended that the application ensure that the
 * receiver is already waiting to receive prior to this function being called.
 * In that case, this will behave like a non-blocking call.
 * 
 * @param c_frame_out   Channel over which to send frame.
 * @param frame         Frame to be transmitted.
 * @param format        Format of `frame[]`.
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
 * This function receives a PCM frame over `c_frame_in` and stores it as a 
 * 32-bit PCM frame in the buffer `frame[]` using the memory layout specified
 * by `format`.
 * 
 * This is a blocking call which does not return until the frame has been 
 * received.
 * 
 * If a 16-bit frame was transmitted (via `ma_frame_tx_s16()`), the 32-bit 
 * elements of `frame[]` will store the corresponding `int16_t` in the least
 * significant 16 bits (i.e. no scaling is applied).
 * 
 * @param frame         Buffer to store received frame.
 * @param c_frame_in    Channel from which to receive frame.
 * @param format        Format of `frame[]`.
 */
MA_C_API
void ma_frame_rx(
    int32_t frame[],
    const chanend_t c_frame_in,
    const unsigned channel_count,
    const unsigned sample_count);


C_API_END