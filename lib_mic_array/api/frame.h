#ifndef PCM_FRAME_H_
#define PCM_FRAME_H_

#define NUM_MICS 8
#define DOUBLE_CHANNELS ((NUM_MICS+1)/2)
#define FRAME_SIZE_LOG2        (0)

/* Two channels of raw PCM audio */
typedef struct {
    int ch_a;
    int ch_b;
} double_packed_audio;

/* Complex number in cartesian coordinates */
typedef struct {
    int re;
    int im;
} complex;


/* Complex number in polar coordinates */
typedef struct {
    int hyp;
    int theta;
} polar;

/* A frame of  */
typedef struct {
    int data[8][1<<FRAME_SIZE_LOG2];
} frame_audio;

typedef struct {
    complex data[DOUBLE_CHANNELS][1<<FRAME_SIZE_LOG2];
} frame_complex;

typedef struct {
    polar data[DOUBLE_CHANNELS][1<<FRAME_SIZE_LOG2];
} frame_polar;

#endif /* PCM_FRAME_H_ */
