#ifndef DEFINES_H_
#define DEFINES_H_

// This defines the number of sample in a frame
//#define FRAME_SIZE_LOG2        (0)
/*
//Applies DC offset removal to the raw audio
#define APPLY_DC_OFFSET_REMOVAL 0

//Apply auto gain control to the raw audio
#define APPLY_AGC 0

//Applies a windowing function to the frame before any bit reversing of the index
//unsigned windowing_function[1<<FRAME_SIZE_LOG2];
#define APPLY_WINDOW_FUNCTION 0

//Bit reverses the frame indexing
#define APPLY_BIT_REVERSING   0
*/
#define NUM_MICROPHONES         8
#define MAX_NUM_CHANNELS        8
#define PDM_BUFFER_LENGTH_LOG2  (10)
#define PDM_BUFFER_LENGTH  ((1<<PDM_BUFFER_LENGTH_LOG2)*MAX_NUM_CHANNELS) / sizeof(unsigned long long)

#endif /* DEFINES_H_ */
