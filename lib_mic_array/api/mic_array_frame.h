// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_FRAME_H_
#define MIC_ARRAY_FRAME_H_

#include <stdint.h>
#include "mic_array_conf.h"

#ifndef MIC_ARRAY_NUM_MICS
    #warning Count of microphones not defined in mic_array_conf.h, defaulting to 16
    #define MIC_ARRAY_NUM_MICS 16
#endif

//Frames of frequency domain audio always have even number of channels, this rounds up.
#define MIC_ARRAY_NUM_FREQ_CHANNELS ((MIC_ARRAY_NUM_MICS + 1)/2)

//This must have an even number of words
typedef struct {
    int32_t min;                /**<The minimum data value in this frame. UNUSED*/
    int32_t max;                /**<The maximum data value in this frame. UNUSED */
    unsigned frame_number;  	/**<The frame_number. UNUSED*/
    unsigned x;  		        /**<Padding. UNUSED*/
} mic_array_metadata_t;

/** Complex number in Cartesian coordinates.*/
typedef struct {
#if MIC_ARRAY_WORD_LENGTH_SHORT
    int16_t re;     /**<The real component. */
    int16_t im;     /**<The imaginary component. */
#else
    int32_t re;     /**<The real component. */
    int32_t im;     /**<The imaginary component. */
#endif
} mic_array_complex_t;

/** A frame of raw audio.*/
typedef struct {
    long long alignment; 		/**<Used to force double work alignment. */
#if MIC_ARRAY_WORD_LENGTH_SHORT
    int16_t data[MIC_ARRAY_NUM_MICS][1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2];/**< Raw audio data*/
#else
    int32_t data[MIC_ARRAY_NUM_MICS][1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2];/**< Raw audio data*/
#endif
    mic_array_metadata_t metadata[2]; /**< Frame metadata (Used internally)*/
} mic_array_frame_time_domain;

/** A frame of frequency domain audio in Cartesian coordinates.*/
typedef struct {
    long long alignment;		/**<Used to force double work alignment. */
    mic_array_complex_t data[MIC_ARRAY_NUM_FREQ_CHANNELS*2][1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1)]; /**< Complex audio data (Cartesian)*/
    mic_array_metadata_t metadata[2]; /**< Frame metadata (Used internally)*/
} mic_array_frame_frequency_domain;

/** A frame of audio preprocessed for direct insertion into an FFT.*/
typedef struct {
    long long alignment;		/**<Used to force double work alignment. */
    mic_array_complex_t data[MIC_ARRAY_NUM_FREQ_CHANNELS][1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2]; /**< Complex audio data (Cartesian)*/
    mic_array_metadata_t metadata[2]; /**< Frame metadata (Used internally)*/
} mic_array_frame_fft_preprocessed;


#endif /* MIC_ARRAY_FRAME_H_ */
