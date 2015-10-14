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


Intended use
------------
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

No high resolution
..................

The PDM microphone interface and the 4 channel deciamtors are instantiated as 
parallel tasks that run in a ``par`` statement. The 4 channel deciamtors must 
connect to the PDM interface via streaming channels.

For example, the following code instantiates a PDM microphone interface
and connects an application to it::

  in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
   
  int main() {
     par {
        decimator_config dc0, dc1;
        streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
        streaming chan c_ds_output_0, c_ds_output_1;
    
        //setup the p_pdm_mics clocking here
    
    	//setup the decimator configuration here
    
        par {
            pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
            decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0, dc0);
            decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1, dc1);
            application(c_ds_output_0, c_ds_output_1,);
        }
    }
    return 0;
  }

With high resolution
....................

The PDM microphone interface, the high resolution delay and the 4 channel deciamtors 
are instantiated as parallel tasks that run in a ``par`` statement. The high
 resolution delay task must reside on the same tile as the PDM interface task as 
 they communicate via a shared memory. The 4 channel deciamtors must 
connect to the high resolution delay via streaming channels.

For example, the following code instantiates a PDM microphone interface with high 
resolution delay and connects an application to it::

  in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
   
  int main() {
     par {
     
        hires_delay_config hrd_config;
        hires_delay_config * unsafe config = &hrd_config;
        decimator_config dc0, dc1;
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

             decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0, dc0);
             decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1, dc1);

             application(c_ds_output_0, c_ds_output_1, config);
        } 
    }
    return 0;
  }


Four Channel Decimator
----------------------
The four channel decimator tasks are highly configurable for outputting frames of 
various sizes. They can be used to produce frames suitable for time domain applications
or perprocess the frames ready for and FFT for frequency domain applications. The four 
channel decimators, decimate_to_pcm_4ch(), have a number of configuration options 
controlled by the structre decimator_config. The configuration is preformed before 
instiantiating the task by configuring the structure decimator_config. It controls 
the following :

* frame_size_log2: This sets the frame size to a power of two. A frame will contain 
  2 to the power of frame_size_log2 samples of each channel. 
* apply_dc_offset_removal: This controls if the DC offset removal should be enabled
  or not. Set to non-sero to enable.
* index_bit_reversal: If enabled this will bit reverse the index of each sample as 
  is typical before preforming and FFT.
* windowing_function: A pointer to an array of integers can be provided to allow
  a windowing function to be applied to the data prior to applying an FFT. This is 
  preformed before any index bit reversal. 
* fir_decimation_factor: This specifies the deciamtion factor to apply to the input
  after a factor of 8 decimator has already been applied. The valid values are 1 to 8 
  inclusive.
* coefs: This is a pointer to an array of arrays containing the coefficients for the 
  final stage of deciamtion. The array should have the same number of entries as the 
  fir_decimation_factor.
* data: This is the memory used to save the FIR samples. It must be 
  4 channels x COEFS_PER_PHASE x sizeof(int) x fir_decimation_factor bytes big.
* apply_mic_gain_compensation: Set this to non-zreo if microphone gain compensation is 
  required. The compensation applied is controlled by mic_gain_compensation.
* mic_gain_compensation: This is a 4 element array specifying the relative compensation
  to apply to each microphone. Unity gain is given by the value 0xffffffff, therefore 
  microphones need to be scaled to the microphone of the least gain.
  
The output of the decimator is 32bit PCM audio at the requested sample rate. 

For example:
* PDM clock of 3.072MHz, with a fir_decimation_factor of 3 would give 16kHz output rate,
* PDM clock of 3.072MHz, with a fir_decimation_factor of 6 would give 8kHz output rate,
* PDM clock of 2.8224MHz, with a fir_decimation_factor of 1 would give 44.1kHz output rate.

The achieveable rates of a 3.072MHz input clock are:
* 48kHz
* 24kHz
* 16kHz
* 12kHz
* 9.6kHz
* 8kHz
* 6.857kHz
* 6kHz

The achieveable rates of a 2.8224MHz input clock are:
* 44.1kHz
* 22.05kHz
* 14.7kHz
* 11kHz
* 8.82kHz
* 7.kHz
* 6.3kHz
* 5.51kHz

High resolution delay 
---------------------


Example Applications
--------------------



API
---

Supporting types
................

.. doxygenenum:: hires_delay_config

.. doxygenstruct:: decimator_config


|newpage|

Creating an PDM Microphone interface instance
.............................................

.. doxygenfunction:: pdm_rx

.. doxygenfunction:: pdm_rx_hires_delay

|newpage|

PDM Microphone processing
.........................

.. doxygenfunction:: hires_delay

.. doxygenfunction:: decimate_to_pcm_4ch

|newpage|

PCM frame interfacing
.....................

.. doxygenfunction:: decimator_init_audio_frame
.. doxygenfunction:: decimator_get_next_audio_frame
.. doxygenfunction:: decimator_init_complex_frame
.. doxygenfunction:: decimator_get_next_complex_frame

|newpage|

Known Issues
------------

No known issues.

.. include:: ../../../CHANGELOG.rst
