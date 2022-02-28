#pragma once

#include "etc/xcore_compat.h"
#include "mic_array/framing.h"
#include "bfp_math.h"

#include <stdint.h>

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif

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
void ma_frame_tx_s32(
    const chanend_t c_frame_out,
    const int32_t frame[],
    const ma_frame_format_t* format);


/**
 * @brief Transmit 16-bit PCM frame over channel.
 * 
 * This function transmits the 16-bit PCM frame `frame[]` over the channel 
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
 * Because all sample elements are transmitted as 32-bit words, each element of
 * `frame[]` is cast to `int32_t` prior to transmit, without any bit shift
 * being applied.
 * 
 * @param c_frame_out   Channel over which to send frame.
 * @param frame         Frame to be transmitted.
 * @param format        Format of `frame[]`.
 */
void ma_frame_tx_s16(
    const chanend_t c_frame_out,
    const int16_t frame[],
    const ma_frame_format_t* format);


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
void ma_frame_rx_s32(
    int32_t frame[],
    const chanend_t c_frame_in,
    const ma_frame_format_t* format);


/**
 * @brief Receive 16-bit PCM frame over channel.
 * 
 * This function receives a PCM frame over `c_frame_in` and stores it as a 
 * 16-bit PCM frame in the buffer `frame[]` using the memory layout specified
 * by `format`.
 * 
 * This is a blocking call which does not return until the frame has been 
 * received.
 * 
 * Whether the transmitting thread is sending a 16-bit or 32-bit frame, all
 * sample elements are transmitted as 32-bit words over the channel. Each
 * received element has a signed arithmetic right-shift of `sample_shr` bits
 * applied prior to being stored in `frame[]`.
 * 
 * If the transmitter is sending a 16-bit frame, a `sample_shr` value of `0` is
 * usually right. 
 * 
 * If a 32-bit frame is transmitted, a `sample_shr` value of `16`will guarantee 
 * samples don't saturate or overflow. However, if the source frame is known to
 * always have `N` bits of headroom (i.e. at least `N` leading sign bits for all 
 * elements), then a `sample_shr` value of `16-N` will maximize precision.
 * 
 * @param frame         Buffer to store received frame.
 * @param c_frame_in    Channel from which to receive frame.
 * @param format        Format of `frame[]`.
 * @param sample_shr    Signed arithmetic right-shift applied to received 
 *                      samples.
 */
void ma_frame_rx_s16(
    int16_t frame[],
    const chanend_t c_frame_in,
    const ma_frame_format_t* format,
    const right_shift_t sample_shr);


/**
 * @brief Receive 32-bit PCM frame pointer over channel.
 * 
 * This function receives a pointer to a PCM frame over channel `c_frame_in` and
 * returns it.
 * 
 * This is a blocking call which does not return until the pointer has been
 * received.
 * 
 * @par Memory Space Limitation
 * 
 * Because a raw pointer is being transmitted, this function should not be used
 * when the transmitting core is on another tile, as it will not be able to
 * access the underlying sample data.
 * 
 * @par Data Integrity
 * 
 * Care must be taken when receiving a frame in this manner, as there are no
 * inherent guarantees that the underlying frame data will not be clobbered
 * by the transmitting thread immediately after transfer. It is the user's
 * responsibility to ensure that this function is only used where the data is
 * known to be valid for as long as it is needed. In many cases, that may only
 * need to be long enough to copy the required data into a new buffer, safe
 * from clobbering.
 * 
 * @param c_frame_in    Channel from which frame pointer is received.
 * 
 * @returns   Pointer to received frame buffer.
 */
int32_t* ma_frame_rx_ptr(
    const chanend_t c_frame_in);


/**
 * @brief Transmit 32-bit PCM sample over channel.
 * 
 * A call to this function is equivalent to a call to `ma_frame_tx_s32()` with
 * a format indicating only a single sample per frame.
 * 
 * @param c_sample_out  Channel over which to transmit sample.
 * @param sample        Sample to be transmitted.
 * @param channel_count Number of channels in received sample.
 */
static inline
void ma_sample_tx_s32(
    const chanend_t c_sample_out,
    const int32_t sample[],
    const unsigned channel_count);


/**
 * @brief Transmit 16-bit PCM sample over channel.
 * 
 * A call to this function is equivalent to a call to `ma_frame_tx_s16()` with
 * a format indicating only a single sample per frame.
 * 
 * @param c_sample_out  Channel over which to transmit sample.
 * @param sample        Sample to be transmitted.
 * @param channel_count Number of channels in received sample.
 */
static inline
void ma_sample_tx_s16(
    const chanend_t c_sample_out,
    const int16_t sample[],
    const unsigned channel_count);


/**
 * @brief Receive 32-bit PCM sample over channel.
 * 
 * A call to this function is equivalent to a call to `ma_frame_rx_s32()` with
 * a format indicating only a single sample per frame.
 * 
 * @param sample        Buffer to store received sample.
 * @param c_sample_in   Channel from which to receive sample.
 * @param channel_count Number of channels in received sample.
 */
static inline
void ma_sample_rx_s32(
    int32_t sample[],
    const chanend_t c_sample_in,
    const unsigned channel_count);


/**
 * @brief Receive 16-bit PCM sample over channel.
 * 
 * A call to this function is equivalent to a call to `ma_frame_rx_s16()` with
 * a format indicating only a single sample per frame.
 * 
 * @param sample        Buffer to store received sample.
 * @param c_sample_in   Channel from which to receive sample.
 * @param channel_count Number of channels in received sample.
 * @param sample_shr    Signed arithmetic right-shift applied to received sample.
 */
static inline
void ma_sample_rx_s16(
    int16_t sample[],
    const chanend_t c_sample_in,
    const unsigned channel_count,
    const right_shift_t sample_shr);

#if defined(__XC__) || defined(__cplusplus)
}
#endif

#include "impl/frame_transfer_impl.h"