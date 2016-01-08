// Copyright (c) 2015, XMOS Ltd, All rights reserved
#ifndef PCM_FRAME_H_
#define PCM_FRAME_H_

#define MAX_NUM_MICS 8
#include <stdint.h>

#include "mic_array_conf.h"

//This must have an even number of words
typedef struct {
    int32_t min;                /**<The minimum data value in this frame. UNUSED*/
    int32_t max;                /**<The maximum data value in this frame. */
    unsigned frame_number;  /**<The frame_number. UNUSED*/
    unsigned x;  /**<The frame_number. UNUSED*/
} s_metadata;

/** Complex number in Cartesian coordinates.*/
typedef struct {
    int32_t re;     /**<The real component. */
    int32_t im;     /**<The imaginary component. */
} complex;

/** Complex number in Polar coordinates.*/
typedef struct {
    int32_t hyp;        /**<The hypotenuse component. */
    int32_t theta;      /**<The angle component. */
} polar;

/** A frame of raw audio.*/
typedef struct {
    int32_t data[MAX_NUM_MICS][1<<MAX_FRAME_SIZE_LOG2];/**< Raw audio data*/
    s_metadata metadata[2];
} frame_audio;

/** A frame of frequency domain audio in Cartesian coordinates.*/
typedef struct {
    complex data[MAX_NUM_MICS/2][1<<MAX_FRAME_SIZE_LOG2];
    s_metadata metadata[2];
} frame_complex;

/** A frame of frequency domain audio in Polar coordinates.*/
typedef struct {
    polar data[MAX_NUM_MICS/2][1<<MAX_FRAME_SIZE_LOG2];
    s_metadata metadata[2];
} frame_polar;

#endif /* PCM_FRAME_H_ */
