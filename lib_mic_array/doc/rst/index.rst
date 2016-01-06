.. include:: ../../../README.rst

Hardware characteristics
------------------------

The signals from the xCORE required to interface to multiple PDM microphones are:

.. _pdm_wire_table:

.. list-table:: PDM microphone data and signal wires
     :class: vertical-borders horizontal-borders
     
     * - *Clock*
       - Clock line, the PDM clock the used by the microphones to 
         drive the data out.
     * - *DQ_PDM*
       - The data from the PDM microphones on an 8 bit port.
       
The only port needed by the library is the data port. It is assumed that the PDM 
microphone is clocked from elsewhere (outside this library). 


Clocking PDM microphones from a master clock
............................................

In the case of the master clock driving the audio subsystem it is desireable to drive the 
PDM microphones from a divided version of the master clock. In such a system where a master 
clock is on a one bit port and the PDM clock is to be driven out on a one bit port then a single
clock block with a hardware divider will drive the PDM microphones with::

  configure_clock_src_divide(pdmclk, p_mclk, 4);
  configure_port_clock_output(p_pdm_clk, pdmclk);
  configure_in_port(p_pdm_mics, pdmclk);
  start_clock(pdmclk);
  

Usage
-----

All PDM microphone functions can be accessed via the ``mic_array.h`` header::

  #include <mic_array.h>

You also have to add ``lib_mic_array`` to the
``USED_MODULES`` field of your application Makefile.

There are two main modes of opperation: with and without high resolution delay. 
With high resolution delay the application can apply individual channel delays 
at the output rate of the PDM interface task (typically 768kHz or 705.6kHz).
This means that samples are outputted into frames synchronously but not necessarly 
phased aligned. When not using high resolution mode the samples are produced 
synchronsly and necessarly phase aligned in time.

An application must also include an extra header ``mic_array_conf.h`` which is used 
to describe the unique configuration of the ``FRAME_SIZE_LOG2`` described later in 
this document.


Phased aligned sampling
.......................

The PDM microphone interface and the 4 channel deciamtors are instantiated as 
parallel tasks that run in a ``par`` statement. The 4 channel deciamtors must 
connect to the PDM interface via streaming channels.

For example, the following code instantiates a PDM microphone interface
and connects an application to it::
  
  in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
  
  int main() {
     par {
        streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
        streaming chan c_ds_output_0, c_ds_output_1;
    
        //setup the p_pdm_mics clocking here
    
    	//setup the decimator configuration here
    
        par {
            pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
            decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
            decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
            application(c_ds_output_0, c_ds_output_1,);
        }
    }
    return 0;
  }

With high resolution delay lines
................................

The PDM microphone interface, the high resolution delay and the 4 channel deciamtors 
are instantiated as parallel tasks that run in a ``par`` statement. The high resolution 
delay task must reside on the same tile as the PDM interface task as they communicate 
via a shared memory. The 4 channel deciamtors must connect to the high resolution delay 
via streaming channels. For example, the following 
code instantiates a PDM microphone interface with high resolution delay and connects 
an application to it::
  
  in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
  
  int main() {
     par {
     
        hires_delay_config hrd_config;
        hires_delay_config * unsafe config = &hrd_config;
        streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
        streaming chan c_ds_output_0, c_ds_output_1;
        streaming chan c_sync;
        int64_t shared_memory[PDM_BUFFER_LENGTH] = {0};
        int64_t * unsafe p_shared_memory = shared_memory;
    
        //setup the p_pdm_mics clocking here
    
    	//setup the decimator configuration here
    
    	//setup high resolution delay config here
    
        par {
             pdm_rx_hires_delay(
                    p_pdm_mics,
                    p_shared_memory,
                    PDM_BUFFER_LENGTH_LOG2,
                    c_sync);

             hires_delay(c_4x_pdm_mic_0, c_4x_pdm_mic_1,
                   c_sync, config, p_shared_memory);

             decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
             decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);

             application(c_ds_output_0, c_ds_output_1, config);
        } 
    }
    return 0;
  }


Frames
------
The four channel deciamtors output frames of either raw audio or audio prepared for an FFT.
The define ``FRAME_SIZE_LOG2`` (found in ``mic_array_conf.h``) is a uniquely defined integer 
used to allocate the memory for the frames. This means that all frames structures will allocate 
enough memory to allow for a frame size of two to the power of ``FRAME_SIZE_LOG2`` regardless 
of the size used in the ``decimator_config_common``. It is recommended that the 
``frame_size_log2`` field of ``decimator_config_common`` is always set to ``FRAME_SIZE_LOG2``. 

Raw audio frames
................
These are frames in which the sample data is packed into eight arrays of length two to the power of
``FRAME_SIZE_LOG2``. 

The first index of the ``data`` element of ``frame_audio`` is used to address the
microphone and the second index is used for the sample number with 0 being the oldest.

Complex audio frames
....................
These are frames designed for the use with FFTs. In order to get the frames from the four channel
decimators in the complex frame format the ``index_bit_reversal`` field of the ``decimator_config``
must be non-zero. Additionally, this will bit reverse the index address of every entry to the 
frame as is normal for a decimate in time(DIT) FFT implementation. To increase efficiency sample data is
packed such that two microphones are packed into a single complex array where one microphone is
used to fill the real values and the other microphone is used to fill the complex values.

A postprocess function must be applied after the DIT-FFT in order to recover the frequency bins.

Four Channel Decimator
----------------------
The four channel decimator tasks are highly configurable tasks for outputting frames of 
various sizes and formats. They can be used to produce frames suitable for time domain applications
or preprocess the frames ready for an FFT for frequency domain applications. The four 
channel decimators, ``decimate_to_pcm_4ch()``, have a number of configuration options 
controlled by the structre ``decimator_config`` through the function ``decimator_configure``. 
The decimators are controlled by two structures: ``decimator_config_common`` and ``decimator_config``, 
where the former config is common to all microphones and the later is specific to the batch of 4
microphones it interfaces to. The application can the option to control the following settings,
decimator_config_common:

* ``frame_size_log2``: This sets the frame size to a power of two. A frame will contain 
  2 to the power of frame_size_log2 samples of each channel. Use the define FRAME_SIZE_LOG2
  for this. 
* ``apply_dc_offset_removal``: This controls if the DC offset removal should be enabled
  or not. Set to non-sero to enable.
* ``index_bit_reversal``: If enabled this will bit reverse the index of each sample as 
  is typical before preforming and FFT.
* ``windowing_function``: A pointer to an array of integers can be provided to allow
  a windowing function to be applied to the data prior to applying an FFT. This is 
  preformed before any index bit reversal. This is not necessary when outputting of raw
  audio frame is required.
* ``fir_decimation_factor``: This specifies the deciamtion factor to apply to the input
  after a factor of 8 decimator has already been applied. The valid values are 1 to 8 
  inclusive.
* ``coefs``: This is a pointer to an array of arrays containing the coefficients for the 
  final stage of deciamtion. The array should have the same number of entries as the 
  ``fir_decimation_factor``. Suitable FIR coefficients have been provided in the header
  ``fir_decimator.h`` and can be easily accessed with the marco ``FIR_LUT(d)`` where
  ``d`` is the ``fir_decimation_factor``.
* ``apply_mic_gain_compensation``: Set this to non-zreo if microphone gain compensation is 
  required. The compensation applied is controlled by ``mic_gain_compensation``.  

decimator_config:

* ``decimator_config_common``: This is a pointer to the common configuration.
* ``data``: This is the memory used to save the FIR samples. It must be 
  4 channels x ``COEFS_PER_PHASE`` x ``sizeof(int)`` x ``fir_decimation_factor`` bytes big.
* ``mic_gain_compensation``: This is a 4 element array specifying the relative compensation
  to apply to each microphone. Unity gain is given by the value ``INT_MAX``, therefore 
  microphones need to be scaled to the microphone of the least gain.
  
The output of the decimator is 32bit PCM audio at the requested sample rate. 

For example:

* PDM clock of 3.072MHz, with a fir_decimation_factor of 3 would give 16kHz output rate,
* PDM clock of 3.072MHz, with a fir_decimation_factor of 6 would give 8kHz output rate,
* PDM clock of 2.8224MHz, with a fir_decimation_factor of 1 would give 44.1kHz output rate.

The achieveable rates of a 3.072MHz input clock are:

* FIR decimation factor of 1 - 48kHz
* FIR decimation factor of 2 - 24kHz
* FIR decimation factor of 3 - 16kHz
* FIR decimation factor of 4 - 12kHz
* FIR decimation factor of 5 - 9.6kHz
* FIR decimation factor of 6 - 8kHz
* FIR decimation factor of 7 - 6.857kHz
* FIR decimation factor of 8 - 6kHz

The achieveable rates of a 2.8224MHz input clock are:

* FIR decimation factor of 1 - 44.1kHz
* FIR decimation factor of 2 - 22.05kHz
* FIR decimation factor of 3 - 14.7kHz
* FIR decimation factor of 4 - 11.025kHz
* FIR decimation factor of 5 - 8.82kHz
* FIR decimation factor of 6 - 7.kHz
* FIR decimation factor of 7 - 6.3kHz
* FIR decimation factor of 8 - 5.51kHz

High resolution delay 
---------------------
The high resolution delay task, ``hires_delay()``, is capable to implementing delays 
with a resolution of up to 1.3 microseconds. 




Example Applications
--------------------
Examples of of how to set up high resolution delay are given in the application 
``app_high_resolution_delay_example`` with a worked example of a fixed beam delay 
and sum beamformer given in the application ``example_hires_DAS_fixed``. Examples 
of of how to set up phased aligned sampling are given in the application 
``app_synchronous_delay_example`` with a worked example of a fixed beam delay and 
sum beamformer given in the application ``example_lores_DAS_fixed``.

API
---

Creating an PDM Microphone interface instance
.............................................

.. doxygenfunction:: pdm_rx
.. doxygenfunction:: pdm_rx_hires_delay

|newpage|

PDM Microphone processing
.........................

.. doxygenfunction:: hires_delay
.. doxygenstruct:: hires_delay_config
.. doxygenfunction:: hires_delay_set_taps
.. doxygenfunction:: decimate_to_pcm_4ch
.. doxygenstruct:: decimator_config_common
.. doxygenstruct:: decimator_config

|newpage|

PCM frame interfacing
.....................

.. doxygenenum:: e_decimator_buffering_type
.. doxygenfunction:: decimator_init_audio_frame
.. doxygenfunction:: decimator_get_next_audio_frame
.. doxygenfunction:: decimator_init_complex_frame
.. doxygenfunction:: decimator_get_next_complex_frame

|newpage|

Frame types
...........

.. doxygenstruct:: complex
.. doxygenstruct:: polar
.. doxygenstruct:: frame_audio
.. doxygenstruct:: frame_complex
.. doxygenstruct:: frame_polar

|newpage|

Known Issues
------------

This is an early release of the library and has not been through formal release testing.  This revision is only intended for internal XMOS use. 

.. include:: ../../../CHANGELOG.rst
