// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_FRAME_H_
#define MIC_ARRAY_FRAME_H_

#include <stdint.h>
#include "mic_array_conf.h"
#include "dsp_fft.h"

#ifndef MIC_ARRAY_WORD_LENGTH_SHORT
    #define MIC_ARRAY_WORD_LENGTH_SHORT 0
#endif

#ifndef MIC_ARRAY_NUM_MICS
    #warning Count of microphones not defined in mic_array_conf.h, defaulting to 16
    #define MIC_ARRAY_NUM_MICS 16
#endif

#if (MIC_ARRAY_NUM_MICS%4) != 0
    #warning Count of microphones(channels) must be set to a multiple of 4
    #if (MIC_ARRAY_NUM_MICS/4) == 0
        #undef MIC_ARRAY_NUM_MICS
        #define MIC_ARRAY_NUM_MICS 4
        #warning MIC_ARRAY_NUM_MICS is now set to 4
    #elif (MIC_ARRAY_NUM_MICS/4) == 1
        #undef MIC_ARRAY_NUM_MICS
        #define MIC_ARRAY_NUM_MICS 8
        #warning MIC_ARRAY_NUM_MICS is now set to 8
    #elif (MIC_ARRAY_NUM_MICS/4) == 2
        #undef MIC_ARRAY_NUM_MICS
        #define MIC_ARRAY_NUM_MICS 12
        #warning MIC_ARRAY_NUM_MICS is now set to 12
    #elif (MIC_ARRAY_NUM_MICS/4) == 3
        #undef MIC_ARRAY_NUM_MICS
        #define MIC_ARRAY_NUM_MICS 16
        #warning MIC_ARRAY_NUM_MICS is now set to 16
    #else
        #error Too many microphones defined
    #endif
#endif

//Frames of frequency domain audio always have even number of channels, this rounds up.
#define MIC_ARRAY_NUM_FREQ_CHANNELS ((MIC_ARRAY_NUM_MICS + 1)/2)

//This must have an even number of words
typedef struct {
    unsigned sig_bits[4];                /**<A bit mask of the absolute values of all samples in a channel.*/
    unsigned frame_number;  	         /**<The frame number.*/
    unsigned x;  		                 /**<Padding. UNUSED*/
} mic_array_metadata_t;

/** Complex number in Cartesian coordinates.*/
#if MIC_ARRAY_WORD_LENGTH_SHORT
    typedef dsp_complex_short_t mic_array_complex_t;
#else
    typedef dsp_complex_t mic_array_complex_t;
#endif

/** A frame of raw audio.*/
typedef struct {
    long long alignment; 		/**<Used to force double work alignment. */
#if MIC_ARRAY_WORD_LENGTH_SHORT
    int16_t data[MIC_ARRAY_NUM_MICS][1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2];/**< Raw audio data*/
#else
    int32_t data[MIC_ARRAY_NUM_MICS][1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2];/**< Raw audio data*/
#endif
    mic_array_metadata_t metadata[(MIC_ARRAY_NUM_MICS+3)/4]; /**< Frame metadata*/
} mic_array_frame_time_domain;

/** A frame of frequency domain audio in Cartesian coordinates.*/
typedef struct {
    long long alignment;		/**<Used to force double work alignment. */
    mic_array_complex_t data[MIC_ARRAY_NUM_FREQ_CHANNELS*2][1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1)]; /**< Complex audio data (Cartesian)*/
    mic_array_metadata_t metadata[(MIC_ARRAY_NUM_MICS+3)/4]; /**< Frame metadata (Used internally)*/
} mic_array_frame_frequency_domain;

/** A frame of audio preprocessed for direct insertion into an FFT.*/
typedef struct {
    long long alignment;		/**<Used to force double work alignment. */
    mic_array_complex_t data[MIC_ARRAY_NUM_FREQ_CHANNELS][1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2]; /**< Complex audio data (Cartesian)*/
    mic_array_metadata_t metadata[(MIC_ARRAY_NUM_MICS+3)/4]; /**< Frame metadata (Used internally)*/
} mic_array_frame_fft_preprocessed;


#endif /* MIC_ARRAY_FRAME_H_ */
