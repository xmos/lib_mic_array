#ifndef PCM_FRAME_H_
#define PCM_FRAME_H_

#define NUM_MICS 8
#define DOUBLE_CHANNELS ((NUM_MICS+1)/2)
#define FRAME_SIZE_LOG2        (0)

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



/* A frame of raw audio*/
typedef struct {
    int data[8][1<<FRAME_SIZE_LOG2];
} frame_audio;

/* A frame of frequency domain audio in cartesian coordinates*/
typedef struct {
    complex data[DOUBLE_CHANNELS][1<<FRAME_SIZE_LOG2];
} frame_complex;

/* A frame of frequency domain audio in polar coordinates*/
typedef struct {
    polar data[DOUBLE_CHANNELS][1<<FRAME_SIZE_LOG2];
} frame_polar;

#endif /* PCM_FRAME_H_ */
