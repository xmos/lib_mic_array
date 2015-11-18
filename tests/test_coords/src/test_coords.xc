#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>

#define PI (3.141592653589793238462643383279502)
#include "coord.h"

unsigned random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return x;
}

#define EPSILON (0.00001)

void tester(){
    int error = 0;

    //Walk along the x-axis
    for(double r=-4.0; r < 4.0; r += 0.05){
        polar_f pf = {r, 0.0, PI/2.0};
        cart_f cf = polar_f_to_cart_f(pf);
        if((fabs(cf.x - r  ) > EPSILON)) error++;
        if((fabs(cf.y - 0.0) > EPSILON)) error++;
        if((fabs(cf.z - 0.0) > EPSILON)) error++;
    }
    printf("Float-Walk along the x-axis: %d\n", error);

    //Walk along the y-axis
    for(double r=-4.0; r < 4.0; r += 0.05){
        polar_f pf = {r, PI/2.0, PI/2.0};
        cart_f cf = polar_f_to_cart_f(pf);
        if((fabs(cf.x - 0.0) > EPSILON)) error++;
        if((fabs(cf.y - r  ) > EPSILON)) error++;
        if((fabs(cf.z - 0.0) > EPSILON)) error++;
    }
    printf("Float-Walk along the y-axis: %d\n", error);

    //Walk along the z-axis
    for(double r=-4.0; r < 4.0; r += 0.05){
        polar_f pf = {r, 0.0, 0.0};
        cart_f cf = polar_f_to_cart_f(pf);
        if((fabs(cf.x - 0.0) > EPSILON)) error++;
        if((fabs(cf.y - 0.0) > EPSILON)) error++;
        if((fabs(cf.z - r  ) > EPSILON)) error++;
    }
    printf("Float-Walk along the z-axis: %d\n", error);

    //Walk along the x-axis
    for(int32_t r=-32; r < 32; r += 1){
        polar_i pf = {r, 0.0, PI/2.0};
        cart_i cf = polar_i_to_cart_i(pf);
        if((fabs(cf.x - r  ) > EPSILON)) error++;
        if((fabs(cf.y - 0.0) > EPSILON)) error++;
        if((fabs(cf.z - 0.0) > EPSILON)) error++;
    }
    printf("Integer-Walk along the x-axis: %d\n", error);

    //Walk along the y-axis
    for(int32_t r=-32; r < 32; r += 1){
        polar_f pf = {r, PI/2.0, PI/2.0};
        cart_f cf = polar_f_to_cart_f(pf);
        if((fabs(cf.x - 0.0) > EPSILON)) error++;
        if((fabs(cf.y - r  ) > EPSILON)) error++;
        if((fabs(cf.z - 0.0) > EPSILON)) error++;
    }
    printf("Integer-Walk along the y-axis: %d\n", error);

    //Walk along the z-axis
    for(int32_t r=-32; r < 32; r += 1){
        polar_f pf = {r, 0.0, 0.0};
        cart_f cf = polar_f_to_cart_f(pf);
        if((fabs(cf.x - 0.0) > EPSILON)) error++;
        if((fabs(cf.y - 0.0) > EPSILON)) error++;
        if((fabs(cf.z - r  ) > EPSILON)) error++;
    }
    printf("Integer-Walk along the z-axis: %d\n", error);


    unsigned x=0x12345678;
    for(unsigned i=0;i<1024;i++){

        cart_i ci = {random(x)>>8, random(x)>>8, random(x)>>8};
        polar_f pf = cart_i_to_polar_f(ci);
        cart_i co = polar_f_to_cart_i(pf);

        int d = co.x - ci.x;
        error |= (d*d > 1);
        d = co.y - ci.y;
        error |= (d*d > 1);
        d = co.z - ci.z;
        error |= (d*d > 1);

    }
    printf("Random points: %d\n", error);
    _Exit(1);

    return;
}

int main(){

    tester();

    return 0;
}

