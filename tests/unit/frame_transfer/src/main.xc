
#include "app.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

unsafe {



int main() {

  xscope_config_io(XSCOPE_IO_BASIC);
  
  par {
    on tile[1]: {
      

      par {
        // Launch mic array thread
        {
          if(PDM_RX_AS_ISR){
            app_setup_pdm_rx_isr(MIC_COUNT, FRAME_SIZE, USE_DCOE);
          }

          app_decimator_task(MIC_COUNT, FRAME_SIZE, USE_DCOE, 
                              (chanend_t) c_audio_frames);
        }

        // If running Pdm Rx as a thread, run it
        {
          if(! PDM_RX_AS_ISR){
            app_pdm_rx_task(MIC_COUNT, FRAME_SIZE, USE_DCOE);
          }
        }

        // Consume frames
        eat_frames(c_audio_frames);
      }
    }
  }

  return 0;
}

}
