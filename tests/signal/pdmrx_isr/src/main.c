// Copyright 2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <xcore/parallel.h>

#include "app.h"

DECLARE_JOB(assert_when_timeout, (void));
DECLARE_JOB(test, (void));

int main()
{
  PAR_JOBS(
    PJOB(test, ()),
    PJOB(assert_when_timeout, ())
  );
  return 0;
}
