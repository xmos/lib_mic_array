#include <stdint.h>

struct channels {
    uint64_t power;
    int chan_number;
};

int find_median(struct channels inp[], int N, uint64_t cut_off);
