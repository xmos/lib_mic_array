// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <platform.h>
#include <xscope.h>

#include "app.h"

#ifndef USE_ISR
# error USE_ISR must be defined.
#endif 

unsafe {


// We cannot be guaranteed to read less than this, and we cannot read more than
// this
#define BUFF_SIZE    256

void host_words_to_app(
    chanend c_from_host,
    streaming chanend c_to_app)
{
  xscope_connect_data_from_host(c_from_host);

  // +3 is for any partial word at the end of the read. It will get moved to the
  // front and we'll read again, which could be another BUFF_SIZE bytes
  char buff[100*BUFF_SIZE+3];
  int buff_lvl = 0;

  /*
    The host app can attempt to send [0, 255] bytes on a write attempt. The
    xscope logic always adds a null byte at the end, so we expect to receive
    [1,256] bytes here. We ignore the null byte at the end, and just consider
    the other bytes (i.e. we pretend we received one fewer byte). Then here's
    the basic protocol:

      - Loop forever:
        - Receive N bytes of data. (after subtracting 1)
        - if N > 0: send all whole words to app and loop back.
        - if N == 0:
          - Enter inner (command) loop:
            - Listen for 1 word (4 bytes) from host:
            - assert() 4 bytes were received
            - Interpret command based on received word value:
              - CMD 0: break from command loop back to data loop
              - CMD 1: terminate application
    
    The reason for the command loop is so that the application can terminate
    gracefully. This design should also make it relatively easy to add 
    additional commands if need be.
  */
  while(1){
    int dd;
    select {
      case xscope_data_from_host(c_from_host, &buff[0], dd):
      {
        dd--; // last byte is always 0 (for some reason)
        buff_lvl += dd;

        if(dd == 0){
          // Enter command loop

          // use a separate buffer in case there is a fractional word in the
          // data buffer.
          char cmd_buff[BUFF_SIZE];
          int cmd_loop = 1;
          while(cmd_loop){
            int pp;
            select {
              case xscope_data_from_host(c_from_host, &cmd_buff[0], pp):
              {
                assert( (pp-1) == 4 );
                uint32_t cmd = ((uint32_t*)(void*) &cmd_buff[0])[0];
                if(cmd == 0){
                  // Break back to data loop
                  printf("[CMD] Resume data loop.\n");
                  cmd_loop = 0;
                } else if (cmd == 1){
                  // Terminate application
                  printf("[CMD] Terminate application.\n");
                  exit(0);
                } else if (cmd == 2){
                  // Print filters
                  printf("[CMD] Print Filters.\n");
                  app_print_filters();
                  cmd_loop = 0;
                } else {
                  // Unknown command.
                  printf("[CMD] Unknown command.\n");
                  assert(0);
                }
                break;
              }
            }
          }

        } else {
          
          // Send all (complete) words to app
          int* next_word = ((int*) (void*) &buff[0]);
          while(buff_lvl >= sizeof(int)){
            c_to_app <: next_word[0];
            next_word++;
            buff_lvl -= sizeof(int);
            // We have to be careful about how quickly we push data to the PDM
            // rx service. Sending too quickly can mess stuff up or (if PDM rx
            // is running in ISR mode) cause a deadlock. This is unfortunate,
            // but is only because we're pretending a channel is a port.
            // Ultimately, we just need to avoid sending PDM data faster than
            // the decimator thread can process the data. Unfortunately, because
            // frames are being used, we don't actually know when it's done
            // processing a given block of data.  So, we'll just insert a 
            // reasonable delay here.

            // With a 3.072 MHz PDM clock and 1 microphone, we expect to have
            // port reads at a rate of 3.072 MHz / 32 = 96 kHz. That rate is
            // linear in the number of channels, but we're also always safe if
            // we go slower than we need to here.  (96 kHz)^(-1) = 10.41 us
            delay_microseconds(15);
          }

          // if there's 1-3 bytes left move it to the front.
          if(buff_lvl) memmove(&buff[0], &next_word[0], buff_lvl);
        }
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
  chan c_frames;

  par {
    xscope_host_data(c_from_host);

    on tile[0]: {
      host_words_to_app(c_from_host, c_to_app);
    }

    on tile[0]: {
      xscope_mode_lossless();

#if (USE_ISR)
      app_pdm_rx_isr_setup((chanend_t) c_to_app);
#endif

      par {
#if !(USE_ISR)
        app_pdm_task((chanend_t) c_to_app);
#endif
        app_dec_task((chanend_t) c_frames);
        app_output_task((chanend_t) c_frames);
      }
    }
  }
  return 0;
}

}