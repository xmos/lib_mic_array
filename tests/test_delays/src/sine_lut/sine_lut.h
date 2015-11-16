#ifndef SIN_LUT_H_
#define SIN_LUT_H_
#include "sine_lut_const.h"

/*
 * define theta of 0 to SINE_LUT_INPUT_MASK as 0 to 2*pi
 * return sin(theta)
 */
int sine_lut_sin(unsigned theta);
int sine_lut_sin_xc(unsigned theta);

/*
 * define theta of 0 to SINE_LUT_INPUT_MASK as 0 to 2*pi
 * return cos(theta)
 */
int sine_lut_cos(unsigned theta);

/*
 * define theta of 0 to SINE_LUT_INPUT_MASK as 0 to 2*pi
 * return sin(theta) and cos(theta)
 */
{int, int} sine_lut_sin_cos(unsigned theta);
#endif /* SIN_LUT_H_ */
