lib_mic_array change log
========================

4.0.0
-----

  * Added mic_dual, an optimised single core, 16kHz, two channel version
  * ADDED: Support for arbitrary frame sizes
  * ADDED: #defines for mic muting
  * ADDED: Non-blocking interface to decimators for 2 mic setup
  * CHANGED: Build files updated to support new "xcommon" behaviour in xwaf.

3.2.0
-----

  * Added xwaf build system support
  * Cleaned up some of the code in the FIR designer.
  * Removed fixed gain in examples
  * Update VU meter example
  * Fix port types in examples
  * Set and inherit XCC_FLAGS rather than XCC_XC_FLAGS when building library

3.1.1
-----

  * Updated lib_dsp dependancy from 3.0.0 to 4.0.0

3.1.0
-----

  * Modified the FIR designer to increase the first stage stopband attenuation.
  * Cleaned up some of the code in the FIR designer.
  * Updated docs to reflect the above.

3.0.2
-----

  * Update DAC settings to work for mic array base board as well.

3.0.1
-----

  * Filter design script update for usability.
  * Documentation improvement.
  * Changed DEBUG_UNIT to XASSERT_UNIT to work with lib_xassert.
  * Added upgrade advisory.
  * Added dynamic range subsection to documentation.

3.0.0
-----

  * Added ability to route internal channels of the output rate of the mic_array
    to the mic_array so that they can benefit from the post processing of the
    mic_array.
  * Enabled the metadata which delivers the frame counter.
  * Small fix to the filter generator to allow the use of fewer taps in the
    final stage FIR.
  * Added significant bits collection to the metadata.
  * Added fixed gain control through define MIC_ARRAY_FIXED_GAIN.
  * Tested and enabled the debug mode for detecting frame dropping. Enabled by
    adding DEBUG_MIC_ARRAY to the Makefile.
  * Moved to using types from lib_dsp.
  * Bug fix in python FIR generator script resulting in excessive output ripple.
  * Default FIR coefficients now optimised for 16kHz output sample rate.
  * Added ability to remap port pins to channels.
  * MIC_ARRAY_NUM_MICS is now forced to a multiple of 4 with a warning if it
    changed.
  * Corrected MIC_ARRAY_DC_OFFSET_LOG2 default value reporting in documentation.

  * Changes to dependencies:

    - lib_dsp: Added dependency 3.0.0

2.0.1
-----

  * Updated AN00221 to use new lib_dsp API for FFTs
  * Updates required for latest lib_mic_array_board_support API

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

