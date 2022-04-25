// Copyright 2020-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <platform.h>
#include <xscope.h>

void run(streaming chanend);

unsafe {


// We can't be guaranteed to read less than this, and we cannot read more than
// this
#define BUFF_SIZE    256

void host_words_to_app(
    chanend c_from_host,
    streaming chanend c_to_app)
{
  xscope_connect_data_from_host(c_from_host);

  // +3 is for any partial word at the end of the read
  char buff[BUFF_SIZE+3];
  int buff_lvl = 0;

  while(1){
    int dd;
    select {
      case xscope_data_from_host(c_from_host, &buff[0], dd):
      {
        dd--; // last byte is always 0 (for some reason)
        buff_lvl += dd;
        // printf("& Received %d bytes.\n", dd);
        
        // Send all (complete) words to app
        int* next_word = ((int*) (void*) &buff[0]);
        while(buff_lvl >= sizeof(int)){
          c_to_app <: next_word[0];
          next_word++;
          buff_lvl -= sizeof(int);
        }

        // if there's 1-3 bytes left move it to the front.
        if(buff_lvl) memmove(&buff[0], &next_word[0], buff_lvl);

        break;
      }
    }

    // repeat forever
  }
}


int main()
{
  chan c_from_host;
  streaming chan c_to_app;

  par {
    xscope_host_data(c_from_host);

    on tile[0]: {
      host_words_to_app(c_from_host, c_to_app);
    }

    on tile[0]: {
      xscope_mode_lossless();
      run(c_to_app);
      printf("Done.\n");
      exit(0);
    }
  }
  return 0;
}

}