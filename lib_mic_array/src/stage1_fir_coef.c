
#include <stdint.h>



// Each coefficient is 16 bits and the number of coefficients must be a multiple of 256.
// int32_t type so that it's word-aligned. So this is 1024 16-bit coefficients. So there
// are 4 coefficient blocks with this
const int16_t pdm_to_pcm_coef[512] = {
 0   // astew: I don't currently have coefficients to use here. 
};