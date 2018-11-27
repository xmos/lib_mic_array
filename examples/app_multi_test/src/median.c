#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "median.h"

int find_median(struct channels inp[], int N, uint64_t cut_off) {
    for(int x = 0; x < N; x++) {
        for(int y = x+1; y < N; y++) {
            if (inp[x].power > inp[y].power) {
                struct channels t = inp[x];
                inp[x] = inp[y];
                inp[y] =t;
            }
        }
    }
#ifdef DEBUG
    for(int x = 0; x < N; x++) {
        printf("%2d ", inp[x].chan_number);
    }
    for(int x = 0; x < N; x++) {
        printf("%3llu ", inp[x].power>>14);
    }
#endif
    for(int x = 0; x < N; x++) {
        if (inp[x].power >= cut_off) {
            return inp[N-(N-x)/2].chan_number;
        }
    }
    return -1;    
}
