
#include "app_config.h"
#include "mips.h"
#include "app_pll_ctrl.h"

#include "app_mic_array.h"
#include "app_i2c.h"
#include "app_i2s.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>


// 16000 smp/s * 5 s * 4 B/smp =  320000 B
#define CAP_SECONDS   5
#define SAMP_COUNT  (CAP_SECONDS * APP_AUDIO_PIPELINE_SAMPLE_RATE)
int32_t audio_capture[SAMP_COUNT];
unsigned k = 0;




void capture(streaming chanend c_in)
{
  while(k < SAMP_COUNT){
    c_in :> audio_capture[k];
    k++;
  }


  printf("\n\n");
  for(k = 0; k < SAMP_COUNT; k++){
    printf("%ld, ", audio_capture[k]);
  }
  printf("\n\n");

  printf("Done!\n\n");
  assert(0);
}



unsafe{
int main() {
  
  streaming chan c_samp_cap;

  par {
    on tile[0]: capture(c_samp_cap);
    on tile[0]: {

      // // uint32_t tmp1[8] = {0x0, 0xffffffff, 0x0, 0xfffc0000, 0x1fff, 0x80000000, 0x7fffffff, 0x80000000};
      // // uint32_t tmp1[8] = {0xffffffff, 0x00000000, 0x00003fff, 0xfff80000, 0x00000001, 0xfffffffe, 0x00000001, 0x00000000};
      // uint32_t tmp1[8] = {0xBEF34417, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000};
      // uint16_t tmp2[16] = { 0x4417, 0xBEF3, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
      //                       0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000  };

      // // memset(tmp1, 0xFF, sizeof(tmp1));

      // int16_t  vD_out[16] = {0};
      // uint16_t vR_out[16] = {0};

      // asm volatile("vclrdr\n");
      // asm volatile("ldc r11, 32; shl r11, r11, 3; vsetc r11" ::: "r11");
      // asm volatile("vldc %0[0]"     :: "r"(tmp1)   );
      // asm volatile("vlmaccr1 %0[0]" :: "r"(tmp2)   );
      // asm volatile("vstd %0[0]"     :: "r"(vD_out) );
      // asm volatile("vstr %0[0]"     :: "r"(vR_out) );

      // int32_t res = (((int32_t) vD_out[0]) << 16) | ((int32_t) vR_out[0]);

      // printf("res: %ld\t(0x%08X)\n", res, (unsigned) res);


      // printf("\n\n\n");
      // delay_milliseconds(2);
      // assert(0);
      

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);
      printf("Running..\n");


      printf("Initializing I2C... ");
      i2c_init();
      printf("DONE.\n");
    }


    on tile[1]: {

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);

      app_pll_init();

      app_mic_array_setup_resources();

      par {
        {
          // delay_seconds(1);
          app_mic_array_enable_isr();
          count_mips();
        }
        {
          app_i2s_task( (unsigned) c_samp_cap);
          printf("I2S stopped.\n");
        }

        print_mips();
      }
    }
  }

  return 0;
}

}
