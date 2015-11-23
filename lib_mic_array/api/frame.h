// Copyright (c) 2015, XMOS Ltd, All rights reserved
#ifndef PCM_FRAME_H_
#define PCM_FRAME_H_

#define NUM_MICS 8

#include "mic_array_conf.h"

//This must have an even number of words
typedef struct {
    int min;                /**<The minimum data value in this frame. UNUSED*/
    int max;                /**<The maximum data value in this frame. */
    unsigned frame_number;  /**<The frame_number. UNUSED*/
    unsigned x;  /**<The frame_number. UNUSED*/
} s_metadata;

/** Complex number in Cartesian coordinates.*/
typedef struct {
    int re;     /**<The real component. */
    int im;     /**<The imaginary component. */
} complex;

/** Complex number in Polar coordinates.*/
typedef struct {
    int hyp;        /**<The hypotenuse component. */
    int theta;      /**<The angle component. */
} polar;

/** A frame of raw audio.*/
typedef struct {
    int data[NUM_MICS][1<<FRAME_SIZE_LOG2];/**< Raw audio data*/
    s_metadata metadata[2];
} frame_audio;

/** A frame of frequency domain audio in Cartesian coordinates.*/
typedef struct {
    complex data[NUM_MICS/2][1<<FRAME_SIZE_LOG2];
    s_metadata metadata[2];
} frame_complex;

/** A frame of frequency domain audio in Polar coordinates.*/
typedef struct {
    polar data[NUM_MICS/2][1<<FRAME_SIZE_LOG2];
    s_metadata metadata[2];
} frame_polar;

#endif /* PCM_FRAME_H_ */
