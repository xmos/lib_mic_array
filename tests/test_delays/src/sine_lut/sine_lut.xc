#include <xs1.h>
#include "sine_lut_const.h"
#include "sine_lut_data.h"
#include "sine_lut.h"

#pragma unsafe arrays
int sine_lut_sin_xc(unsigned theta){

    unsigned p = theta >> (SINE_LUT_INPUT_BITS-2);
    theta = theta>>(SINE_LUT_INPUT_BITS - SINE_LUT_BITS-2);

    if(p&1) theta = -theta;

    unsigned val = zext(theta, SINE_LUT_BITS);

    unsigned short l = sin_lut[val];

    int sine_theta = (int)l;

    if((!val) && (p&1)) sine_theta = SINE_LUT_OUTPUT_MAX_MAGNITUDE;

    if(p&2)
        sine_theta = -sine_theta;

    return sine_theta;
}

#pragma unsafe arrays
int sine_lut_cos_xc(unsigned theta){

    unsigned p = theta >> (SINE_LUT_INPUT_BITS-2);
    theta = theta>>(SINE_LUT_INPUT_BITS - SINE_LUT_BITS-2);

    if(!(p&1)) theta = -theta;

    unsigned val = zext(theta, SINE_LUT_BITS);

    unsigned short l = sin_lut[val];

    int sine_theta = (int)l;

    if((!val) && (!(p&1))) sine_theta = SINE_LUT_OUTPUT_MAX_MAGNITUDE;

    if(p==2 || p == 1)
        sine_theta = -sine_theta;

    return sine_theta;
}
