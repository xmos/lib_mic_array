#ifndef COORD_H_
#define COORD_H_
#include <stdint.h>
#include <limits.h>

//This represents 1m or 2pi
#define COORD_SCALE_FACTOR (1<<24)

typedef struct {
    int32_t r;
    int32_t theta;
    int32_t phi;
} polar_i;

typedef struct {
    double r;
    double theta;
    double phi;
} polar_f;

typedef struct {
    int32_t x;
    int32_t y;
    int32_t z;
} cart_i;

typedef struct {
    double x;
    double y;
    double z;
} cart_f;

cart_i polar_f_to_cart_i(polar_f p);
polar_f cart_i_to_polar_f(cart_i c);

cart_f polar_f_to_cart_f(polar_f p);
polar_f cart_f_to_polar_f(cart_f c);

double   get_dist_polar_f(polar_f a, polar_f b);
uint32_t get_dist_polar_i(polar_i a, polar_i b);
double   get_dist_cart_f(cart_f a, cart_f b);
uint32_t get_dist_cart_i(cart_i a, cart_i b);



#endif /* COORD_H_ */
