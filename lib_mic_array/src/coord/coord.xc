
#include "coord.h"
#include <math.h>

cart_i polar_f_to_cart_i(polar_f p){
    double X = p.r*sin(p.phi)*cos(p.theta)*COORD_SCALE_FACTOR;
    double Y = p.r*sin(p.phi)*sin(p.theta)*COORD_SCALE_FACTOR;
    double Z = p.r*cos(p.phi)*COORD_SCALE_FACTOR;

    int x = (int)X;
    int y = ((int)Y)%COORD_SCALE_FACTOR;
    int z = ((int)Z)%COORD_SCALE_FACTOR;

    cart_i c = {x, y, z};
    return c;
}

polar_f cart_i_to_polar_f(cart_i c){
    double X = (double)c.x;
    double Y = (double)c.y;
    double Z = (double)c.z;

    X /= (double)COORD_SCALE_FACTOR;
    Y /= (double)COORD_SCALE_FACTOR;
    Z /= (double)COORD_SCALE_FACTOR;

    double r = sqrt(X*X + Y*Y + Z*Z);
    double theta = atan2(Y, X);
    double phi = atan2(sqrt(X*X + Y*Y), Z);

    polar_f p = {r, theta, phi};
    return p;
}

cart_f polar_f_to_cart_f(polar_f p){
    double X = p.r*sin(p.phi)*cos(p.theta);
    double Y = p.r*sin(p.phi)*sin(p.theta);
    double Z = p.r*cos(p.phi);
    cart_f c = {X, Y, Z};
    return c;
}

polar_f cart_f_to_polar_f(cart_f c){
    double X = c.x;
    double Y = c.y;
    double Z = c.z;

    double r = sqrt(X*X + Y*Y + Z*Z);
    double theta = atan2(Y, X);
    double phi = atan2(sqrt(X*X + Y*Y), Z);

    polar_f p = {r, theta, phi};

    return p;
}

double get_dist_polar_f(polar_f a, polar_f b){

    double x0 = a.r*sin(a.phi)*cos(a.theta);
    double x1 = b.r*sin(b.phi)*cos(b.theta);
    double y0 = a.r*sin(a.phi)*sin(a.theta);
    double y1 = b.r*sin(b.phi)*sin(b.theta);
    double z0 = a.r*cos(a.phi);
    double z1 = b.r*cos(b.phi);

    double x = x0-x1;
    double y = y0-y1;
    double z = z0-z1;

    return sqrt(x*x + y*y + z*z);
}


uint32_t get_dist_polar_i(polar_i a, polar_i b){
    return 0;
}

double   get_dist_cart_f(cart_f a, cart_f b){
    return 0.0;
}

uint32_t get_dist_cart_i(cart_i a, cart_i b){
    return 0;
}
