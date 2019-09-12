.. include:: ../../../README.rst

Overview
--------

This guide is designed so that the user can understand how to use ``lib_mic_array``
by reading up to :ref:`section_examples`. :ref:`section_dc` and on are designed to explain 
implementation details of ``lib_mic_array``, but do not need to be understood to use 
it effectively.

Up to sixteen PDM microphones can be attached to each high channel count PDM
interface (``mic_array_pdm_rx()``). One to four processing tasks, ``mic_array_decimate_to_pcm_4ch()``, 
each process up to four channels. For 1-4 channels the library requires two logical cores:

  .. figure:: chan4.pdf
	:width: 100%
	    
	One to four channel count PDM interface

or for 5-8 channels three logical cores as shown below:

  .. figure:: chan8.pdf
            :width: 100%
                    
            Five to eight count PDM interface

|newpage|

9-12 channels requires 5 logical cores and for 13-16 channels three six cores as shown below:

  .. figure:: chan16.pdf
            :width: 100%
                    
            Thirteen to sixteen count PDM interface

The left most task, ``mic_array_pdm_rx()``, samples up to 8 microphones and filters the data to provide up to
eight 384 kHz data streams, split in two streams of four channels. The processing thread
decimates the signal to a user chosen sample rate (one of 48, 24, 16, 12,
or 8 kHz). If more than 8 channels are required then another ``mic_array_pdm_rx`` task can be created.
After the decimation to the output sample rate the following steps takes place:

* Any DC offset is eliminated on the each channel.

* The gain is corrected so that a maximum signal on the PDM microphone
  corresponds to a maximum signal on the PCM signal.

* The individual gain of each microphone can be compensated.
  This can be used to compensate any differences in gains between the microphones in a system.

* Frames of data are generated (with a frame size of 1 to 8192 in powers of two).
  Frames can be set to overlap by half a frame.

* An optional windowing function is applied to each frame.

* The data can be stored in an index bit-reversed manner, so that it can be passed
  into an FFT without having to do any preprocessing.


There is also an optional high resolution delay, running at up to 384kHz, that can be used to add to the 
signal path channel specific delays. This can be used for high resolution delay and sum
beamforming. The task diagrams for 4 and 8 channel microphone arrays are given in 
:ref:`figfourchanhires` and :ref:`figeightchanhires` respectively.

.. _figfourchanhires:
.. figure:: chan4hires.pdf
	:width: 100%
	    
	One to four channel count PDM interface with hires delay lines


.. _figeightchanhires:
.. figure:: chan8hires.pdf
            :width: 100%
                    
            Five to eight count PDM interface with hires delay lines

Higher channel counts are simple extensions of the above task diagrams. The high resolution delay task 
requires a single extra core for up to 16 channels. All tasks requires a 62.5 MIPS core to run correctly, 
therefore, all eight cores can be used simultaneously without timing problems developing
within ``lib_mic_array``.

Version upgrade advisory
------------------------

2.+ -> 3.+
............

When upgrading from version 2 to 3 the main interface change is from the function ``mic_array_decimate_to_pcm_4ch()``.
In version 2::

            void mic_array_decimate_to_pcm_4ch(
                    streaming chanend c_from_pdm_interface);

And in version 3::

            void mic_array_decimate_to_pcm_4ch(
                    streaming chanend c_from_pdm_interface,
                    streaming chanend c_frame_output, mic_array_internal_audio_channels * channels);

This new parameter is used for feeding internal audio channels into the decimators so that the internal channels 
can benefit from the post decimation processing that the microphones receive (metadata collection, windowing, etc).
In order to upgrade a version 2 mic array to version 3 simply use the define ``MIC_ARRAY_NO_INTERNAL_CHANS`` for 
the new parameter in the above function.


Typical memory usage
--------------------

The memory usage of ``lib_mic_array`` is mostly dependent on the desired output rates and 
the maximum number of channels. As lower output rates require greater decimation from the 
input PDM their memory requirements are proportionally greater also. Below is a table of the 
approximate memory usage against the channel count and decimation factor for each 
final stage divider.

  =================== =============== ==========================
   Decimation factor   Channel count   Approx memory usage (kB)
  =================== =============== ==========================
   2                   4               12.1
   2                   8               14.1
   2                   12              16.1
   2                   16              18.1
   4                   4               13.1
   4                   8               16.1
   4                   12              19.1
   4                   16              21.1
   6                   4               14.1
   6                   8               18.1
   6                   12              22.1
   6                   16              26.1
   8                   4               15.1
   8                   8               20.1
   8                   12              25.1
   8                   16              30.1
   12                  4               17.1
   12                  8               24.1
   12                  12              31.1
   12                  16              38.1
  =================== =============== ==========================
  
These values should be use as a guide as actual memory usage may vary slightly.


Hardware characteristics
------------------------

The PDM microphones need a *clock input* and provide the PDM signal on a
*data output*. All PDM microphones share the same clock signal (buffered on
the PCB as appropriate), and output onto eight data wires that are
connected to a single 8-bit port:

.. _pdm_wire_table:

.. list-table:: PDM microphone data and signal wires
     :class: vertical-borders horizontal-borders
     
     * - *CLOCK*
       - Clock line, the PDM clock the used by the microphones to 
         drive the data out.
     * - *DQ_PDM*
       - The data from the PDM microphones on an 8 bit port.
       
The only port passed into the library is the 8-bit data port. The library
assumes that the input port is clocked using the PDM clock and 
requires no knowledge of PDM clock source. If a clock block ``pdmclk``
is clocked at a 3.072 MHz rate, and the 8-bit port is p_pdm_mics then 
the following statements will ensure that the PDM data
port is clocked by the PDM clock::

  configure_in_port(p_pdm_mics, pdmclk);
  start_clock(pdmclk);

The input clock for the microphones can be generated in a multitude of
ways. For example, a 3.072MHz clock can be generated on the board, or the xCORE can
divide down 12.288 MHz master clock. Or, if clock
accuracy is not important, the internal 100 MHz reference can be divided down to provide an
approximate clock.

If an external master clock is input to the xCORE on a 1-bit port
``p_mclk`` that is running at 4x the desired PDM clock, then the PDM clock
can be generated by using the divider in a clock block::

  configure_clock_src_divide(pdmclk, p_mclk, 4);
  configure_port_clock_output(p_pdm_clk, pdmclk);
  configure_in_port(p_pdm_mics, pdmclk);
  start_clock(pdmclk);
  
An approximate clock can be generated from the 500 MHz xCORE clock as follows::

  configure_clock_xcore(pdmclk, 82);
  configure_port_clock_output(p_pdm_clk, pdmclk);
  configure_in_port(p_pdm_mics, pdmclk);
  start_clock(pdmclk);

It should be noted that this is a 3.049 MHz clock, which is 0.75% off a true
3.072 MHz clock. Finally, an approximate clock can also be generated from the 100 MHz reference
clock as follows::

  configure_clock_ref(pdmclk, 17);
  configure_port_clock_output(p_pdm_clk, pdmclk);
  configure_in_port(p_pdm_mics, pdmclk);
  start_clock(pdmclk);

This gives a 2.941 MHz clock, which is 4.25% off a true 3.072 MHz clock. This may be acceptable 
to simple Voice User Interfaces (VUIs).

PDM microphones
...............

PDM microphones typically have an initialization delay in the order of about 28ms. They also 
typically have a DC offset. Both of these will be specified in the datasheet.

Usage
-----

All PDM microphone functions are accessed via the ``mic_array.h`` header::

  #include <mic_array.h>

You also have to add ``lib_mic_array`` to the
``USED_MODULES`` field of your application Makefile.

A project must also include an extra header ``mic_array_conf.h`` which is used 
to describe the mandatory configuration described later in this document.

The PDM microphone interface and 4-channel decimators are instantiated as 
parallel tasks that run in a ``par`` statement. For example, in an eight channel setup the two 4-channel decimators must 
connect to the PDM interface via streaming channels::

  #include <mic_array.h>
  
  clock pdmclk;
  in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
  in port             p_mclk      = XS1_PORT_1E;  
  out port            p_pdm_clk   = XS1_PORT_1F;
  
  int main() {
        streaming chan c_pdm_to_dec[2];
        streaming chan c_ds_output[2];
    
        configure_clock_src_divide(pdmclk, p_mclk, 4);
        configure_port_clock_output(p_pdm_clk, pdmclk);
        configure_in_port(p_pdm_mics, pdmclk);
        start_clock(pdmclk);
    
        par {
            mic_array_pdm_rx(p_pdm_mics, c_pdm_to_dec[0], c_pdm_to_dec[1]);

            mic_array_decimate_to_pcm_4ch(c_pdm_to_dec[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
            mic_array_decimate_to_pcm_4ch(c_pdm_to_dec[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);

            application(c_ds_output);
        }
        return 0;
  }

There is a further requirement that any application of a ``mic_array_decimate_to_pcm_4ch()`` 
task must be on the same tile as the ``mic_array_decimate_to_pcm_4ch()`` task due to the shared
frame memory.
  
As the PDM interface ``mic_array_pdm_rx()`` communicates over channels then the placement of it
is not restricted to the same tile as the decimators.

Additionally, the high resolution delay task can be inserted between the PDM
interface and the decimators in the following fashion::

  #include <mic_array.h>
  
  clock pdmclk;
  in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
  in port             p_mclk      = XS1_PORT_1E;  
  out port            p_pdm_clk   = XS1_PORT_1F;
  
  int main() {
        streaming chan c_pdm_to_hires[2];
        streaming chan c_hires_to_dec[2];
        streaming chan c_ds_output[2];
        chan c_cmd;
    
        configure_clock_src_divide(pdmclk, p_mclk, 4);
        configure_port_clock_output(p_pdm_clk, pdmclk);
        configure_in_port(p_pdm_mics, pdmclk);
        start_clock(pdmclk);
    
        par {
            mic_array_pdm_rx(p_pdm_mics, c_pdm_to_hires[0], c_pdm_to_hires[1]);

            mic_array_hires_delay(c_pdm_to_hires, c_hires_to_dec, 2, c_cmd);

            mic_array_decimate_to_pcm_4ch(c_hires_to_dec[0], c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
            mic_array_decimate_to_pcm_4ch(c_hires_to_dec[1], c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);

            application(c_ds_output, c_cmd);
        }
        return 0;
  }
  
  
Note, using the high resolution delay consumes an extra logical core.


High resolution delay task
--------------------------
The high resolution delay task, ``mic_array_hires_delay()``, is capable of implementing delays 
with a resolution down to 2.3 microseconds (384kHz). It implements up to 16 delays lines of length 
``MIC_ARRAY_HIRES_MAX_DELAY``, which has a default of 256. The delay line length can be overridden 
by redefining it in ``mic_array_conf.h``. Each delay line sample is clocked at the PDM clock
rate divided by 8, that is, 384kHz for a 3.072MHz PDM clock and 352.8kHz for an PDM clock
of 2.8224MHz.

By setting a positive delay of ``N`` samples on a channel then an input sample will take N extra 
clocks to propagate to the decimators. Setting of the taps is done through the function 
``mic_array_hires_delay_set_taps()`` which will do an atomic update of all the active delay lines tap 
positions. The default delay on each channel is zero.
When the high resolution delay task is in use the define ``MIC_ARRAY_HIRES_MAX_DELAY`` should be 
minimised for the application specific requirements as longer delay lines require more memory.

See :ref:`section_api` for the API.


Accessing the samples
---------------------
Samples are accessed in the form of frames. A frame is returned from the decimators in either the time 
domain format, ``mic_array_frame_time_domain``, or in the FFT ready format, 
``mic_array_frame_fft_preprocessed``.

Time domain frames contain a single two-dimensional array, ``data``,with the first dimension being the 
channel ID and the second dimension being the sample number. Samples are ordered ``0`` as the oldest 
sample and increasing number being newer.

FFT ready frames also contain a single two-dimensional array, ``data``. The data is preprocessed by the decimators
in such a way that the frames that are ready for direct processing by an DIT FFT.

  .. _figmemory:
  .. figure:: memory_layout.pdf
	:width: 70%
	    
	Memory layout of simple audio and complex frames.

Frames in the ``mic_array_frame_fft_preprocessed`` are not intended to be directly accessed by a user. Instead
when the frame has been processed by the FFT and cast to a ``mic_array_frame_frequency_domain`` then the
data can be manipulated.
	

Frames
------

The four channel decimators (``mic_array_pdm_rx()``) output frames of either *time domain audio* or
*FFT ready audio* prepared for an FFT. The define ``MIC_ARRAY_MAX_FRAME_SIZE_LOG2``
(found in ``mic_array_conf.h``) should be used to allocate the arrays to
store the frames. This means that all frames structures will allocate
enough memory to allow for a frame size of two to the power of
``MIC_ARRAY_MAX_FRAME_SIZE_LOG2`` regardless of the size used in the
``decimator_config_common``. It is recommended that the ``len``
field of ``decimator_config_common`` is always set to ``MIC_ARRAY_MAX_FRAME_SIZE_LOG2``.
Equally, the define ``MIC_ARRAY_NUM_MICS`` is used for allocating the memory
for the frame structure. This must be set to a multiple of 4.

All frame types contain a two-dimensional ``data`` array. 

For simplicity of reading ``M`` will represent two to the power of ``MIC_ARRAY_MAX_FRAME_SIZE_LOG2`` and
``F`` will represent two to the power of ``len``.

Time domain frames
..................

If *time domain audio* output is used (``index_bit_reversal`` is set to 0), then
data is stored into arrays in real time ordering. The arrays are of length ``M`` where 
the first ``F`` (see :ref:`section_api`) entries contain valid data. All 
entries between ``F`` and ``M`` are undefined. The first index of the ``data`` 
element of the structure ``mic_array_frame_time_domain`` is used to address the 
channel and the second index is used for the sample number with zero being the 
oldest sample.

Frames are initialised by the application with a call to ``mic_array_init_time_domain_frame()``. Pass it:

* ``c_from_decimators``: An array of channels to the decimators.

* ``decimator_count``: A count of the number of decimators (the number of
  elements in the above array).

* ``buffer``: used internally to maintain ownership of the shared memory between  
  the application and the decimators.

* ``audio``: the array of audio frames, one (or two) of which will be owned by the 
  decimators at all times.

* ``dc``: the configuration array to the decimators.

Calls to ``mic_array_get_next_time_domain_frame()`` should be made to retrieve
subsequent audio frames. These calls require the exact same parameters as 
``mic_array_init_time_domain_frame()``.

FFT ready audio
...............

If *FFT ready audio* output is used (``index_bit_reversal`` is set to 1),
then the data is stored in frames that are designed to be processed with an
FFT. The data is stored in arrays of length ``M`` where the first two ``F`` 
entries contain valid data, each element storing a real and an imaginary
part. The data is stored in a bit reversed order (ie, the oldest element is
at index 0b0000....0000, the next oldest is at element 0b1000...0000, the
next one at element 0b0100...0000, etc up to element 0b1111...1111), and
the real elements store the even channels, whereas the imaginary elements
store the odd channels. A postprocess function must be applied after the
Decimate-in-Time (DIT) FFT in order to recover the frequency bins.

Frames are initialised by the application by a call to
``mic_array_init_frequency_domain_frame()``. Pass it:

* ``c_from_decimator``: An array of channels to the decimators

* ``decimator_count``: A count of the number of decimators (the number of
  elements in the above array).

* ``buffer``: used internally to maintain ownership of the shared memory between  
  the application and the decimators.

* ``f_complex``: the array of complex frames, one (or two) of which will be owned by the 
  decimators at all times.

* ``dcc``: the configuration to the decimators.

Calls to ``mic_array_get_next_frequency_domain_frame()`` should be made to retrieve
subsequent audio frames. These calls require the exact same parameters as 
``mic_array_init_frequency_domain_frame()``.


Metadata
........

The metadata associated with frames is dependent on the final stage decimator ratio. For all
final stage decimators all frames will have metadata attached to them that records the frame number.
The frame counter is a unsigned 32 bit counter. Care must be taken when using this counter
for extended periods as it will wrap (at 48kHz the counter will wrap after ~24hrs). The 
frame counter will increment every time a frame is accepted. 

When the final stage decimator is greater than 2 (corresponding to output sample rate of 24kHz 
or 22.05kHz) then extra metadata will be collected. The metadata reported is:

* ``sig_bits``: A mask of the significant bits used within the frame to represent the all the samples. 
  It is literally,  initially ``sig_bits[n] = 0`` then ``sig_bits[n] | abs(s)`` for all ``s`` samples 
  within channel ``n`` of a frame. This is a 4 element array with each element representing a channel.
  The significant bits mask is updated before windowing is applied. This means that if windowing is applied
  then the true number of significant bits may be fewer than the reported number. 

* ``x``: an unused variable to pad the structure for double word alignment.
  

Using the decimators
--------------------

The decimators reduce the high rate PCM down to lower rate PCM. They also prepare the audio
for subsequent algorithms, i.e. framing, windowing, etc.

Setting up the decimators
.........................

All decimators attach to an application via streaming channels and are configured 
simultaneously with the ``mic_array_decimator_configure()`` function. The parameters to the
``mic_array_decimator_configure()`` function are described in a :ref:`section_api`. To start the 
frame exchange process ``mic_array_init_frequency_domain_frame()`` or  
``mic_array_init_time_domain_frame()`` must be called. Now the decimators are running 
and will be outputting frames at the rate given by their configuration.

  .. _figstatemachine:
  .. figure:: state_machine.pdf
	:width: 100%
	    
	Order of the function calls allowed to the decimators.

The configuration of the decimators can be changed at any time so long as the 
function calls respect the control flow given in :ref:`figstatemachine`.
Mixing of time and frequency domain functions is not supported without first calling
``mic_array_decimator_configure()``.

Changing decimator configuration
................................

Once the decimators are running the configuration of the decimators remains constant. If a change of configuration 
is required then a call to ``mic_array_decimator_configure()`` allows a complete reconfigure. This will 
reconfigure and reset all attached decimators. The only configuration that will survive reconfiguration
is the DC offset memory. It is assumed that the microphone specific DC offset 
remains fairly constant between reconfigurations. 

  
``mic_array_conf.h``
--------------------

An application that uses ``lib_mic_array`` must define the header file
``mic_array_conf.h``. This header must define:

   * MIC_ARRAY_MAX_FRAME_SIZE_LOG2

     This defines the maximum frame size (log 2) that the application could request to use.
     The application may request frame sizes from 0 to ``MIC_ARRAY_MAX_FRAME_SIZE_LOG2``. 
     This should be kept small as it governs the memory required for 
     a frame.

   * MIC_ARRAY_NUM_MICS

     This defines the number of microphones in use. It is used for allocating memory in the
	 frame structures. 

Optionally, ``mic_array_conf.h`` may define:

   * MIC_ARRAY_DC_OFFSET_LOG2

     The DC offset is removed with a high pass filter. ``DC_OFFSET_DIVIDER_LOG2``
	 can be used to control the responsiveness of the filter vs the cut off frequency.
	 The default is 8, but setting this will override it. The value must not exceed 31.
	 See :ref:`section_dc` DC offset removal for further explanation.

   * MIC_ARRAY_MIC_ARRAY_HIRES_MAX_DELAY

     This defines the length of the high resolution delay lines. This should be set to a power
	 of two for efficiency. The default is 256. Increasing values will result in increasing memory
	 usage.

   * MIC_ARRAY_WORD_LENGTH_SHORT

     If this define is set to non-zero then this configures the output word length to be a 16 bit 
	 short otherwise its left as 32 bit word length output. All internal processing will be done at
	 32 bits, only during the write to frame memory will the truncation happen.

   * Microphone to channel remapping

     By default pin ``n`` is mapped to channel ``n`` for all the pins of the microphone input 
     port. If a reordering of pins to channels is required then the ordering can be overridden 
     with the define ``MIC_ARRAY_CHn`` and the pin``PINm`` where ``n`` and ``m`` are the channel 
     number and pin number respectively. For example, ``#define MIC_ARRAY_CH0 PIN2`` would map 
     pin 2 of the microphone input port to channel 0. Any undefined channel are left as the default 
     mapping.

   * MIC_ARRAY_FIXED_GAIN

     If this define will apply a fixed gain to the 64 bit output of the final stage decimation FIR. 
     The define should be set to an integer between -32 and +32. The define refers to the 
     amount that the signal should be left shifted by with positive number increasing the 
     signal and negative numbers decreasing the signal. The use of this can cause distortion. 
     There is no saturation logic included in the gain control.

Optionally, ``mic_array_conf.h`` or ``xassert_conf.h`` may define:

   * DEBUG_MIC_ARRAY

     If this define will enable the debugging features of the mic array. These include timing assertions
     and configuration validation. To enable set to non-zero.
	 
Four Channel Decimator
----------------------

The four channel decimator tasks are highly configurable tasks for outputting frames of 
various sizes and formats. They can be used to produce frames suitable for time domain applications
or pre-process the frames ready for an FFT for frequency domain applications. The four 
channel decimators, ``mic_array_decimate_to_pcm_4ch()``, have a number of configuration options 
controlled by the structure ``decimator_config`` through the function ``mic_array_decimator_configure()``. 
The decimators are controlled by two structures: ``decimator_config_common`` and ``decimator_config``, 
where the former configuration is common to all microphones and the later is specific to the batch of 4
microphones it interfaces to. The application has the option to control the
following settings through ``decimator_config_common``:

* ``len``: The length of a frame: an arbitrary value < 2^15. The maximum allowed at run-time is given by two to the
power of ``MIC_ARRAY_MAX_FRAME_SIZE_LOG2``. At run-time the length can be dynamically configured by
setting the ``len`` member of ``mic_array_decimator_config_common``. If ``len``
is less than 16, the frame size will be ``2^len``. If ``len`` is 16 or greater, the
frame size will be ``len``.

* ``apply_dc_offset_removal``: This controls if the DC offset removal should be enabled
  or not. Set to non-zero to enable, or ``0`` to not apply DC offset removal.
  
* ``output_decimation_factor``: This specifies the decimation factor to apply to the PDM input
  after an 8x decimator and 4x decimator has already been applied, i.e. for a 3.072MHz PDM clock the 
  ``output_decimation_factor`` will apply to a 96kHz sample rate. The valid values
  are 2, 4, 6, 8 and 12. Common sample rates can be achieved by using
  these decimation factors as follows:

  ======================== ========== ==============
  output_decimation_factor PDM clock  Sample rate
  ======================== ========== ==============
  2                        3.072 MHz   48 kHz
  4                        3.072 MHz   24 kHz
  6                        3.072 MHz   16 kHz
  8                        3.072 MHz   12 kHz
  12                       3.072 MHz   8 kHz
  2                        2.8224 MHz  44.1 kHz
  4                        2.8224 MHz  22.05 kHz
  ======================== ========== ==============
  
  For other decimation factors see :ref:`section_advanced`.
  
* ``coefs``: This is a pointer to an array of arrays containing the
  coefficients for the final stage of decimation. For the provided 
  decimators set this to ``g_third_stage_div_X_fir`` where ``X`` is 
  the ``output_decimation_factor``.
  If you wish to supply your own FIR coefficients see :ref:`section_advanced`.
  
* ``fir_gain_compensation``: single value to compensate the gain of all the
  previous decimators. This must be set to a value that depends on the
  ``output_decimation_factor`` as follows:
  
  ======================== =======================
  output_decimation_factor fir_gain_compensation
  ======================== =======================
  2                         FIR_COMPENSATOR_DIV_2
  4                         FIR_COMPENSATOR_DIV_4
  6                         FIR_COMPENSATOR_DIV_6
  8                         FIR_COMPENSATOR_DIV_8
  12                        FIR_COMPENSATOR_DIV_12
  ======================== =======================
  
  If you wish to supply your own, this is a fixed point number in 5.27 format. To apply
  a unity gain set to ``0``.
  
* ``apply_mic_gain_compensation``: Set this to ``1`` if microphone gain compensation is 
  required. The compensation applied is controlled through the
  ``mic_gain_compensation`` array in ``decimator_config`` below.
  
* A windowing function can be passed in through ``windowing_function``. It is a pointer
  to an array of integers that defines the windowing operator. Each sample
  in the frame is multiplied by its associated window value and shifted
  right by 31 places. This is performed before any index bit reversal (see
  the next entry). The window function data is in 1.31 fixed point format and only the first half
  of the window function is required.
  
* If the data is going to be post processed using an FFT, then
  ``index_bit_reversal`` can be set to 1. This will store the data elements
  reordered according to a reversed bit pattern, suitable for an FFT
  without "index bit reversing". As a side effect, it stores the data as
  complex numbers, in such a way that a single complex FFT operates on two
  microphones in parallel.

* ``buffering_type``: ``DECIMATOR_HALF_FRAME_OVERLAP`` is used to specify half frame overlapping or sequential 
  frames is selected with ``DECIMATOR_NO_FRAME_OVERLAP``.

* ``number_of_frame_buffers``: is used to specify the number of frames used by the 
  application plus decimators. This number should be at least two when ``DECIMATOR_NO_FRAME_OVERLAP``
  is in effect or three when ``DECIMATOR_HALF_FRAME_OVERLAP`` is in effect. This is due to the double 
  buffered nature of the decimators, i.e. the decimators are writing to (one or two) frames whilst 
  the application is using at least one. 

``decimator_config`` configures the per-channel information:

* ``dcc``: This is a pointer to the common decimator configuration.
  
* ``data``: This is the memory used to save the FIR samples. It must be an
  array of size (4 channels x ``THIRD_STAGE_COEFS_PER_STAGE`` x ``sizeof(int)`` x
  ``output_decimation_factor`` bytes).
  
* ``mic_gain_compensation``: This is an array with four elements specifying
  the relative compensation to apply to each microphone. Unity gain is
  given by the value ``INT_MAX``. To equalise the gain of all microphones,
  the quietest microphone should be given unity gain, and the gain of all
  other microphones should be set proportionally lower.

* ``channel_count``: this is the number of channels that is enabled. Set
  this to 4 to enable all channels. If set to a value less than 4, only the
  first ``channel_count`` channels are enabled.

* ``async_interface_enabled``: This enables the non-blocking decimator interface
  which requires ``frame size == 0`` and the use of ``mic_array_recv_samples``.

The decimator configuration is applied by calling
the function ``mic_array_decimator_configure()`` with an array of chanends referring to
the decimators, a count of the number of decimators, and an array of
decimator configurations.

The output of the decimator is 32-bit or 16-bit(MIC_ARRAY_WORD_LENGTH_SHORT != 0) PCM audio 
at the requested sample rate.
 
Intended usage model
--------------------

The library has been designed with the intention of being able to dynamically 
change its configuration, however, for minimal memory 
footprint choosing a single output rate means the fewest FIR coefficient 
end up in the binary.
A typical code structure will contain the following::

  unsigned buffer;
  mic_array_init_time_domain_frame(c_ds_output, 2, buffer, audio, dc);

  while(1){
    mic_array_frame_time_domain *  latest_frame = mic_array_get_next_time_domain_frame(c_ds_output, 2, buffer, audio, dc);

  }

When a reconfigure is performed then there will be a short interval (to flush the FIR data buffers)
before the audio continues.

Overlapping frames are supported so that frequency domain algorithms can be converted back into the 
time domain without artefacts. See ``lib_dsp`` for FFT functions.
 
The ``number_of_frame_buffers`` member of ``decimator_config_common`` is required so that a frame 
buffer (array) can be used in a round-robin fashion. This means that the when the application calls 
either ``mic_array_init_time_domain_frame()`` or ``mic_array_init_frequency_domain_frame()`` then 
the ownership of one or two of the fames (depending on the overlapping scheme)
will be passed to the decimators. When a decimator has finished writing the oldest frame it is 
returned to the application and the next in line is sent to the decimators. This means that by declaring
larger frame buffers and increasing ``number_of_frame_buffers`` then the application can have visibility
of longer periods of time at the expense of memory.

Due to the round-robin nature of the library the application must be finished with the data in the 
oldest frame before the decimators need it again. This is the nature of real time audio processing.

Note: timing verification can be checked by switching on ``DEBUG_MIC_ARRAY``. This will enable an assertion 
if the application of the decimators does not meet the real time requirements of the audio stream. 


FIR memory
----------

For each decimator a block of memory must be allocated for storing FIR data. The size of the data 
block must be::
  
  Number of channels * THIRD_STAGE_COEFS_PER_STAGE * Decimation factor * sizeof(int)

bytes. The data must also be double word aligned. For example, if the decimation factor was set to 
``DECIMATION_FACTOR`` and two decimators were in use, then the memory allocation for the FIR memory 
would look like::

  int data[CHANNELS][THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

The FIR memory must also be initialized in order to prevent a spurious click during startup. 
Normally initializing to all zeros is sufficient. ``memset`` is a highly efficient way of doing this.

Note, globally declared memory is always double word aligned.


.. _section_examples:

Example Applications
--------------------

Two stand alone applications showing the minimum code required to build a functioning
microphone array are given in ``AN00217_app_high_resolution_delay_example`` and in 
``AN00220_app_phase_aligned_example``. 

A worked example of a fixed beam delay and sum beamformer is given in the application
``AN00219_app_lores_DAS_fixed``. Also examples of of how to set up high resolution delayed 
sampling can be seen in the high resolution fixed beam delay and sum beamformer given 
in the application ``AN00218_app_hires_DAS_fixed``. 
 
.. _section_dc:

DC offset removal
-----------------

The DC offset removal is implemented as a single pole IIR filer obeying the 
relation::

  Y[n] = Y[n-1] * alpha + x[n] - x[n-1]

Where ``alpha`` is defined as ``1 - 2^MIC_ARRAY_DC_OFFSET_LOG2``. Increasing ``MIC_ARRAY_DC_OFFSET_LOG2``
will increase the stability of the filter and decrease the cut off point at the cost of increased 
settling time. Decreasing ``MIC_ARRAY_DC_OFFSET_LOG2`` will increase the cut off point of the filter. 
 

Signal Characteristics
----------------------

Definition of terms
...................

Passband
........
This specifies the bandwidth, from DC, in Hz over which a signal will not be attenuated by more 
than 3dB.

Stopband
........

This specifies the start frequency to the input Nyquist sample rate that the input signal should 
be attenuated over.

.. _section_characteristics:

Characteristics
...............

By default the output signal has been decimated from the original PDM in such a way to introduce no more than 
-70dB of alias noise (during the decimation process) into the passband for all output sample rates.

  ======================== =================== ======================
  output_decimation_factor PDM Sample Rate(Hz) Output sample rate(Hz)
  ======================== =================== ======================
  2                         3072000             48000                 
  4                         3072000             24000                 
  6                         3072000             16000                 
  8                         3072000             12000                 
  12                        3072000             8000                  
  2                         2822400             44100                 
  4                         2822400             22050                  
  6                         2822400             14700                  
  8                         2822400             11025                  
  12                        2822400             7350                   
  ======================== =================== ======================

  ======================== ============ ============ ========== ==========
  output_decimation_factor Passband(Hz) Stopband(Hz) Ripple(dB) THD+N(dB)
  ======================== ============ ============ ========== ==========
  2                         18240        24000        1.40        -144.63
  4                         10080        12480        0.49        -142.61
  6                         6720         8320         0.23        -139.10
  8                         5040         6240         0.18        -136.60
  12                        3360         4160         0.12        -133.07
  2                         16758        22050        1.40        -144.63
  4                         9261         11466        0.49        -142.61
  6                         6174         7644         0.23        -139.10
  8                         4630         5733         0.18        -136.60
  12                        3087         3822         0.12        -133.07
  ======================== ============ ============ ========== ==========

The decimation is achieved by applying three poly-phase FIR filters sequentially. 
The design of these filters can be viewed in the python script ``fir_design.py``. The default 
magnitude responses of the first to third stages are given as :ref:`figthird_stage_div_2` 
through to :ref:`figthird_stage_div_12` in the appendix. The first stage and second stage 
can be viewed in :ref:`figfirst_stage` and :ref:`figsecond_stage`.

Group delay
...........

The group delay of the default filters is 18 output clock cycles. This can be shortened by either using a minimum phase 
FIR as the final stage decimation FIR and/or by reducing the number of taps on the final stage decimation FIR. 

FIR dynamic range
.................

The dynamic range of the decimation FIRs is given as ``(32 - log2(number of taps)) * 6.02``. This gives the first stage
at least 159.0dB of dynamic range, the second stage at least 168.6dB of dynamic range and the third stage with 32 
coefficients per phase as:

  ======================== ====================
  output_decimation_factor  Dynamic Range (dB)
  ======================== ====================
    2                          156.53
    4                          150.51
    6                          146.99
    8                          144.49
    12                         140.97
  ======================== ====================

.. _section_advanced:

Advanced filter design
----------------------

The table in :ref:`section_characteristics` has been generated to provide 70dB of stopband attenuation for all decimation factors
whilst maintaining a fairly flat passband and wide bandwidth. However for a given specification 
the filter characteristics can be optimised to reduce latency, increase passband, lower the 
passband ripple and increase the signal to noise ratio. For example, in a system where a 16kHz
output is required then limiting the passband to 8kHz would improve the other properties. Equally, 
if the noise floor of the PDM microphone is 65dB then there is little advantage exceeding that in the
filter. 

Note, as of version 3.0.0 the default FIR coefficients are optimised for 16kHz output with a stopband 
attenuation of 70dB. Read below to specify custom filter characteristics. To see the exact filter characteristics
``fir_design.py`` can be run, as part of its output the script will write the filter characteristics to the terminal.


``fir_design.py`` usage
.......................
 
In order generate custom filters the ``fir_design.py`` can be executed. The purpose of this script 
is to design and generate the FIR coefficients for the three stages of decimation. ``fir_design.py`` 
is a command line tool that takes a number of options to control each parameter of the
filter design. As previously illustrated the PDM to PCM conversion is divided into three stages. 
The stop band attenuation is controlled for each stage with the options:

* first stage (``--first-stage-stop-atten``) - The stop band attenuation(in dB) of the first stage filter(Normally negative).
* second stage (``--second-stage-stop-atten``) - The stop band attenuation(in dB) of the second stage filter(Normally negative).
* third stage (``--third-stage-stop-atten``) - The stop band attenuation(in dB) of the third stage filter(Normally negative).

In the first stage the designer is then able to tune:

* passband bandwidth (``--first-stage-pass-bw``) - The bandwidth of the passband, in kHz (defaults to 40kHz).
* stopband bandwidth (``--first-stage-stop-bw``) - The bandwidth of the bands around the regions that will alias with the pass band after decimation, in kHz.
* use lowest ripple first stage (``--use-low-ripple-first-stage``) - This uses an alternative filter design to minimise passband ripple at the cost of broadband stopband attenuation.
* num taps (``--first-stage-num-taps``)  - Do not change this

These are illustrated in :ref:`figfirst`.

  .. _figfirst:
  .. figure:: first_stage_diagram.pdf
	:width: 100%
	    
	First stage design parameters.

In the second stage the same options are available:

* passband bandwidth (``--second-stage-pass-bw``) - The bandwidth of the passband, in kHz (defaults to 16kHz).
* stopband bandwidth (``--second-stage-stop-bw``) - The bandwidth of the bands around the regions that will alias with the pass band after decimation, in kHz.

These are illustrated in :ref:`figsecond`.

  .. _figsecond:
  .. figure:: second_stage_diagram.pdf
	:width: 100%
	    
	Second stage design parameters.

In the third stage the designer can provide custom decimation factors in addition to the pass and stop band parameters.
Also the delay of the filter can be controlled by tuning the number of taps to allocate for each phase of
the poly-phase FIR (``--third-stage-num-taps``). The fewer the number of taps per phase then the shorter the
delay of the filter but the harder the design will be to meet other criteria.

To add a custom third stage filter ``--add-third-stage`` has to be called. It requires the following arguments:

* decimation factor - the ratio of input samples to output samples.
* output passband - this specifies where the passband ends.
* output stopband start - this specified where the stopband starts.
* filter_name - this assigns a name to the custom filter.
* num taps - the number of taps to use for each round of the third stage

Examples
........

General Example
...............

For example to add a third stage decimator called "my_filter" with a final stage decimation factor of D, 
output passband of PkHz and output stopband start of S kHz and N taps per phase then the argument ``--add-third-stage D P S my_filter N``
would need to be passed to the script.

These are illustrated in figure :ref:`figthird`.

  .. _figthird:
  .. figure:: third_stage_diagram.pdf
	:width: 100%
	    
	Third stage design parameters.

The filter name is used to generate the defines and coefficient arrays used to implement the filter in ``lib_mic_array``.
The defines ``DECIMATION_FACTOR_ + (filter_name)`` and ``FIR_COMPENSATOR_ + (filter_name)`` will be generated to
represent the filter designed. In the generated defines the name will be in all caps and the FIR coefficients array will 
be in all lowercase. Additionally, the array ``const int g_third_stage_ + (filter_name) _fir[]`` will
also be generated and will contain all the coefficients to implement the filter.
For example, if ``fir_design.py`` was passed the option ``--add-third-stage 2 P S my_filter N`` then available 
in ``lib_mic_array`` would be::
 
  #define DECIMATION_FACTOR_MY_FILTER (2)
  #define FIR_COMPENSATOR_MY_FILTER (301451293)
  extern const int g_third_stage_my_filter_fir[126];


16kHz voice
...........

In this example we would like to optimise for a 16kHz output rate, let's assume that the requirement of 6.7kHz bandwidth is sufficient. We will assume a 3.072MHz PDM clock and that our microphones have a -63dB SNR. This means that a decimation factor of 6 will be required to reduce the output of the second stage (384kHz in this case) down to 16kHz. We would also like to keep the passband ripple to within 0.15dB and have no aliasing in the highest frequencies above -40dB.

Next we only require that each stage of decimation can pass the voice which, by virtue of the 16kHz sample rate, will be output limited to 8kHz of band width. The first decimator is by default over specified so needs no attention. The second stage decimator will introduce high frequency attenuation if the passband is too wide, for this reason we should limit it to our requirements in order to maximise stopband attenuation and minimise ripple. The third stage is where we make the final output decisions; we require 6.7kHz of passband bandwidth but in order to minimise ripple we want to relax the transition region as much as possible without introducing too much aliasing. In order to meet our specification we can set the start of the stop band at 8.15kHz and the stop band attenuation to -65dB.

All this can be captured by the FIR design script::

    python fir_design.py --pdm-sample-rate 3072 --second-stage-pass-bw 6.7 --second-stage-stop-bw 6.7 --add-third-stage 6 6.7 8.15 custom_voice 32 --third-stage-stop-atten -65.0

The resulting filter would be :ref:`figcustomvoice`.

  .. _figcustomvoice:
  .. figure:: output_custom_voice.pdf
	:width: 100%
      
	Custom voice filter.

We can see that as the PDM sample rate was specified then the output magnitude response is displayed on :ref:`figcustomvoice`.

48kHz fullband
..............

In this example we will look at the situation where a 48kHz wideband output is required. This time let's assume that a 14kHz passband is required with -70dB stop band attenuation and 0.3dB of ripple is acceptable. As the all of the default stopband 
attenuations are better than or equal to the desired stopband attenuation then we wont need to modify it. We will need to set 
the bandwidths of the second stage to our new 14kHz requirement. For the third stage tere will be no need for the stop band to exceed the Nyquist rate so we will set it to 24kHz. This can be captured by the FIR design script::

    python fir_design.py --pdm-sample-rate 3072 --second-stage-pass-bw 14 --second-stage-stop-bw 14 --add-third-stage 6 14 24 custom_wideband 32

The resulting filter would be :ref:`figcustomwideband`.

  .. _figcustomwideband:
  .. figure:: output_custom_wideband.pdf
	:width: 100%
      
	Custom wideband filter.

.. _section_api:

API
---

Creating an PDM microphone interface instance
.............................................

.. doxygenfunction:: mic_array_pdm_rx

|newpage|

PDM microphone processing
.........................

.. doxygenfunction:: mic_array_decimate_to_pcm_4ch
.. doxygenfunction:: mic_array_decimator_configure
.. doxygenstruct:: mic_array_decimator_config_t
.. doxygenstruct:: mic_array_decimator_conf_common_t
.. doxygenfunction:: mic_array_init_far_end_channels
.. doxygenfunction:: mic_array_send_sample

|newpage|

PCM frame interfacing
.....................

.. doxygenenum:: mic_array_decimator_buffering_t
.. doxygenfunction:: mic_array_init_time_domain_frame
.. doxygenfunction:: mic_array_get_next_time_domain_frame
.. doxygenfunction:: mic_array_init_frequency_domain_frame
.. doxygenfunction:: mic_array_get_next_frequency_domain_frame

|newpage|

Frame types
...........

.. doxygenstruct:: mic_array_frame_time_domain
.. doxygenstruct:: mic_array_frame_frequency_domain
.. doxygenstruct:: mic_array_frame_fft_preprocessed
.. doxygenstruct:: mic_array_metadata_t

High resolution delay task
..........................

.. doxygenfunction:: mic_array_hires_delay
.. doxygenfunction:: mic_array_hires_delay_set_taps

|newpage|
|appendix|


.. _figfirst_stage:
.. figure:: first_stage.pdf
            :width: 70%
                    
            First stage FIR magnitude response.


.. _figsecond_stage:
.. figure:: second_stage.pdf
            :width: 70%
                    
            Second stage FIR magnitude response.


.. _figthird_stage_div_2:
.. figure:: third_stage_div_2.pdf
            :width: 70%
                    
            Third stage FIR magnitude response for a divide of 2 giving a typical output rate of 48kHz(3.072MHz) or 44.1kHz(2.8224MHz).


.. _figthird_stage_div_4:
.. figure:: third_stage_div_4.pdf
            :width: 70%
                    
            Third stage FIR magnitude response for a divide of 4 giving a typical output rate of 24kHz(3.072MHz) or 22.05kHz(2.8224MHz).


.. _figthird_stage_div_6:
.. figure:: third_stage_div_6.pdf
            :width: 70%
                    
            Third stage FIR magnitude response for a divide of 6 giving a typical output rate of 16kHz(3.072MHz) or 14.7kHz(2.8224MHz).


.. _figthird_stage_div_8:
.. figure:: third_stage_div_8.pdf
            :width: 70%
                    
            Third stage FIR magnitude response for a divide of 8 giving a typical output rate of 12kHz(3.072MHz) or 11.025kHz(2.8224MHz).


.. _figthird_stage_div_12:
.. figure:: third_stage_div_12.pdf
            :width: 70%
                    
            Third stage FIR magnitude response for a divide of 12 giving a typical output rate of 8kHz(3.072MHz) or 7.35kHz(2.8224MHz).



.. _figouput_div_2:
.. figure:: output_div_2.pdf
            :width: 70%
                    
            Final frequency response for a divide of 2 giving a typical output rate of 48kHz(3.072MHz) or 44.1kHz(2.8224MHz).



.. _figouput_div_4:
.. figure:: output_div_4.pdf
            :width: 70%
                    
            Final frequency response for a divide of 4 giving a typical output rate of 24kHz(3.072MHz) or 22.05kHz(2.8224MHz).



.. _figouput_div_6:
.. figure:: output_div_6.pdf
            :width: 70%
                    
            Final frequency response for a divide of 6 giving a typical output rate of 16kHz(3.072MHz) or 14.7kHz(2.8224MHz).



.. _figouput_div_8:
.. figure:: output_div_8.pdf
            :width: 70%
                    
            Final frequency response for a divide of 8 giving a typical output rate of 12kHz(3.072MHz) or 11.025kHz(2.8224MHz).



.. _figouput_div_12:
.. figure:: output_div_12.pdf
            :width: 70%
                    
            Final frequency response for a divide of 12 giving a typical output rate of 8kHz(3.072MHz) or 7.35kHz(2.8224MHz).

				
|newpage|

Known Issues
------------

  * decimator_config channel count is tested for 4 channels per decimator, fewer than 4 is untested.

.. include:: ../../../CHANGELOG.rst
