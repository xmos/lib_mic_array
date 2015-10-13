.. include:: ../../../README.rst

Microphone array library
------------------------



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

The PDM microphone interface and the 4 channel deciamtors are instantiated as 
parallel tasks that run in a ``par`` statement. The 4 channel deciamtors must 
connect to the server via a streaming channel.

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

**Note**: The client and SDRAM server must be on the same tile as the 
line buffers are transferred by moving pointers from one task to another.


Decimator configuration
-----------------------


High resolution delay configuration
-----------------------------------


Example applications
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

Known Issues
------------

No known issues.

.. include:: ../../../CHANGELOG.rst
