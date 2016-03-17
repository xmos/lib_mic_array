lib_mic_array change log
========================

2.0.0
-----

  * Renamed all functions to match library structure
  * Decimator interface functions now take the array of
    mic_array_decimator_config structure rather than
    mic_array_decimator_config_common
  * All defines renames to match library naming policy
  * DC offset simplified
  * Added optional MIC_ARRAY_NUM_MICS define to save memory when using less than
    16 microphones

1.0.1
-----

  * Added dynamic DC offset removal at startup to eliminate slow convergance
  * Mute first 32 samples to allow DC offset to adapt before outputting signal
  * Fixed XTA scripte to ensure timing is being met
  * Now use a 64-bit accumulator for DC offset removal
  * Consolidated generators into a single python generator
  * Produced output frequency response graphs
  * Added 16 bit output mode

1.0.0
-----

  * Major refactor
  * FRAME_SIZE_LOG2 renamed MAX_FRAME_SIZE_LOG2
  * Decimator interface now takes arrays of streaming channels
  * Decimators now take channel count as a parameter
  * Added filter designer script
  * Documentation updates
  * First stage now uses a FIR decimator
  * Changed decimation flow
  * Removed high res delay module
  * Added generator for FIR coefficients
  * Added ability to reduce number of channels active in a decimator
  * Increased number of FIR taps
  * Increased output dynamic range

0.0.2
-----

  * Documentation fixes
  * Fixed frame number fix
  * Added frame metadata

0.0.1
-----

  * Initial Release

  * Changes to dependencies:

    - lib_logging: Added dependency 2.0.0

    - lib_xassert: Added dependency 2.0.0

