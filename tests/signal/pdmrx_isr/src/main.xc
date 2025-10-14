// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <platform.h>
#include <xscope.h>
#include <print.h>

#include "app.h"
#include <stdio.h>
#include <stdlib.h>

//unsafe {
int main()
{
  par {
    on tile[0]: {
      par {
          test();
          assert_when_timeout();
      }
    }
  }
  return 0;
}

//}
