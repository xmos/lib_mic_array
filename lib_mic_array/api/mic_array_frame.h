// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef PCM_FRAME_H_
#define PCM_FRAME_H_

#include <stdint.h>
#include "mic_array_conf.h"

#ifndef MIC_ARRAY_NUM_MICS
    #define MIC_ARRAY_NUM_MICS 16
#endif

#define MIC_ARRAY_NUM_FREQ_CHANNELS ((MIC_ARRAY_NUM_MICS + 1)/2)



//This must have an even number of words
typedef struct {
    int32_t min;                /**<The minimum data value in this frame. UNUSED*/
    int32_t max;                /**<The maximum data value in this frame. UNUSED */
    unsigned frame_number;  	/**<The frame_number. UNUSED*/
    unsigned x;  		        /**<Padding. UNUSED*/
} s_metadata;

/** Complex number in Cartesian coordinates.*/
typedef struct {
#if MIC_ARRAY_WORD_LENGTH_SHORT
    int16_t re;     /**<The real component. */
    int16_t im;     /**<The imaginary component. */
#else
    int32_t re;     /**<The real component. */
    int32_t im;     /**<The imaginary component. */
#endif
} complex;

/** Complex number in Polar coordinates.*/
typedef struct {
    #if MIC_ARRAY_WORD_LENGTH_SHORT
    int32_t hyp;        /**<The hypotenuse component. */
    int32_t theta;      /**<The angle component. */
#else
    int32_t hyp;        /**<The hypotenuse component. */
    int32_t theta;      /**<The angle component. */
#endif
} polar;

/** A frame of raw audio.*/
typedef struct {
    long long alignment;
#if MIC_ARRAY_WORD_LENGTH_SHORT
    int16_t data[MIC_ARRAY_NUM_MICS][1<<MAX_FRAME_SIZE_LOG2];/**< Raw audio data*/
#else
    int32_t data[MIC_ARRAY_NUM_MICS][1<<MAX_FRAME_SIZE_LOG2];/**< Raw audio data*/
#endif
    s_metadata metadata[2]; /**< Frame metadata (Used internally)*/
} frame_audio;

/** A frame of frequency domain audio in Cartesian coordinates.*/
typedef struct {
    long long alignment;
    complex data[MIC_ARRAY_NUM_FREQ_CHANNELS][1<<MAX_FRAME_SIZE_LOG2]; /**< Complex audio data (Cartesian)*/
    s_metadata metadata[2]; /**< Frame metadata (Used internally)*/
} frame_complex;

/** A frame of frequency domain audio in Cartesian coordinates.*/
typedef struct {
    long long alignment;
    complex data[MIC_ARRAY_NUM_FREQ_CHANNELS*2][1<<(MAX_FRAME_SIZE_LOG2-1)]; /**< Complex audio data (Cartesian)*/
    s_metadata metadata[2]; /**< Frame metadata (Used internally)*/
} frame_frequency;

/** A frame of frequency domain audio in Polar coordinates.*/
typedef struct {
    long long alignment;
    polar data[MIC_ARRAY_NUM_FREQ_CHANNELS][1<<MAX_FRAME_SIZE_LOG2]; /**< Complex audio data (Polar)*/
    s_metadata metadata[2]; /**< Frame metadata (Used internally)*/
} frame_polar;

#endif /* PCM_FRAME_H_ */
