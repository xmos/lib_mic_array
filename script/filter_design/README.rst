========================
PDM to PCM Filter Design
========================


Introduction
------------
Conversion of the 1 bit PDM signal at a high sample rate to a 32 bit PCM signal
at a lower sample rate requires several decimation stages. Each filter should
remove the frequencies that will alias into the final passband, this typically
means attenuation by at least 80dB. There are 3 types of stage, all of which
are implemented as FIR filters:

* First stage: moving average filter, decimation of PDM signal by 32.
* Middle stages (optional): half band filter, decimation by 2
* Final stage: low pass filter, decimation to final sample rate.

A 2 stage filter has a simpler implementation, but a 3 or more stage filter
needs fewer computations for the same performance. Python scripts to aid the
design are provided in this folder.


Example designs
---------------

Functions to design 2 and 3 stage decimation filters can be found in
``design_filters.py``. This also contains several example designs:

* ``good_2_stage_filter``: decimation from 3.072 MHz to 16 kHz using 2 stages.
* ``small_2_stage_filter``: as above, but using fewer filter taps in stage 2. 
  This saves memory, at the cost of reduced alias suppression and early
  passband rolloff.
* ``good_3_stage_filter``: similar performance to ``good_2_stage_filter``, but
  over 3 stages instead of 2. This results in fewer computations.
* ``good_32k_filter``: decimation from 3.072 MHz to 32 kHz using 2 stages.

Each example design returns coefficients in a packed format of
``[stage][coefficients, decimation_ratio]``. The filter coefficients are
returned as either float or int. If ``int_coeffs=True``, stage 1 will be int16
and subsequent stages will be int32.

Calling ``python ./script/filter_design/design_filter.py`` will generate a
``.pkl`` file for each example. These can be run though script/stage1.py to
convert the coefficients to hexadecimal values for use in
``lib_mic_array/src/etc/stage1_fir_coef.c``. More details on this process are
in ``script/README.rst``


Plotting utilities
------------------

``plot_coeffs.py`` contains filter response plotting utilities for individual
stages (``plot_stage``) and the combined response (``plot_filters``). Both can
input and output axis handles for comparing filter designs.

When plotting a single stage using ``plot_stage``, the a plot is generated
showing the filter taps in the time domain, and the frequency response of the
filter. The filter response shows the frequency response of the filter at
the input sampling frequency. Frequencies that will be discarded by subsequent
stages are greyed out, frequencies that will alias into the final passband are
left white. These frequencies should have the most attenuation.

The passband response shows the filter response at the output sampling
frequency. The decimated response includes all the aliases, the summed level
of these is shown in green. The alias level in the final passband should be as
low as possible. The passband ripple is the filter response, shown on a zoomed
scale.

``plot_filters`` shows a summary of the individual stages, and the combined
filter response. Passband roll off in stage 1 can be corrected stage 2, giving
a flat combined response.


Designing custom filters
------------------------

Tools for designing custom decimation filter are provided. Generally, at least
80dB of alias attenuation is recommended. More taps is better, but will use
more memory and CPU, and may have rounding issues in Stage 1. Some design
considerations for each stage are detailed below

Stage 1
'''''''
The stage 1 filter starts with a 32 tap moving average filer (``np.ones(32)``),
which is convolved with itself ``ma_stages`` times. This gives a frequency
response with strong nulls at frequencies that will alias into the final
passband. More stages will give more attenuation and widen the nulls. The
number of taps for the final filter is ``(31*ma_stages) + 1``.

The coefficient
values for 4 or fewer stages fits within the range of ``int16``, so no rounding
is required. For 5 or more stages, the range of coefficient values exceeds
``int16`` range, so scaling and rounding is required which will affect the
filter response and increase the level of the aliases. As each stage convolves
``np.ones(32)`` with the previous stage, a good solution is to scale and round
the coefficients at an intermediate stage, allowing the final stages to be
convolved without additional rounding.

Final Stage
'''''''''''
The ideal final stage filter would be a brickwall antialiasing filter (i.e.
8kHz for a 16kHz output). A realistic implementation must balance the flatness
of the passband with the amount of alias attenuation. More taps allows for a
steeper slope, increased alias attenuation and less compromise, but requires
more memory and compute.

The filter is designed using the window method,
typically using a Kaiser window which allows for good control of the filter
slopes (other windows can be specified). The target filter response compensates
for any rolloff in previous stages to give a flat combined filter response,
generally this results in around 1dB rise at higher frequencies. The C
implementation requires the coefficients to be ``int32``, scaling and rounding
to this is not usually an issue.

Optional middle stages
''''''''''''''''''''''
Extra decimation stages can be added after the initial MA filter. This means
the final stage filter runs at a lower sample rate, and so needs fewer taps for
the same performance. Middle stages are expected to decimate by 2, allowing a
half band filter to be used. These filters have a very large transition band as
only frequencies that alias into the final passband need to be attenuated, and
so require very few taps to implement effectively.

If ``(n_taps+1) % 4 == 0``,
then every other tap can be zero. This is achieved by designing the filter at
the output sample rate, then upsampling it to the input sample rate by
inserting zeros between the taps. Coefficients are ``int32``, so scaling and
rounding is not usually an issue.
