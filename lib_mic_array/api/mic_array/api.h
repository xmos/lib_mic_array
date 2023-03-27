// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once


#if defined(__cplusplus)
# define FROM_C     0
# define FROM_CPP   1
# define FROM_XC    0
#elif defined(__XC__)
# define FROM_C     0
# define FROM_CPP   0
# define FROM_XC    1
#else //no explicit definitions for C files
# define FROM_C     1
# define FROM_CPP   0
# define FROM_XC    0
#endif 

// I'd rather call this `C_API`, but there's currently an issue in lib_xs3_math
// where it defines `C_API` without checking whether it's already defined. That
// creates problems depending on the order in which headers are included.
#ifndef MA_C_API
// XC doesn't support marking individual functions as 'extern "C"`. It requires
// use of the block notation.
# if FROM_C || FROM_XC
#  define MA_C_API
# else
#  define MA_C_API   extern "C"
# endif
#endif


#ifndef C_API_START
# if FROM_XC
#  define C_API_START  extern "C" {
# else
#  define C_API_START
# endif
#endif


#ifndef C_API_END
# if FROM_XC
#  define C_API_END   }
# else
#  define C_API_END   
# endif
#endif