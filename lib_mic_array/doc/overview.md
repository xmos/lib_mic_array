

# Introduction

`lib_mic_array` is a library for capturing and processing PDM microphone data on
xcore.ai devices.

PDM microphones are a kind of 'digital' microphone which captures audio data as
a stream of 1-bit samples at a very high sample rate. The high sample rate PDM
stream is captured by the device, filtered and down-sampled to a 
32-bits-per-sample PCM audio stream.

## `lib_mic_array`'s Capabilities

* 1 or 2 threads
* 1 or 2 PDM microphones (4, 8 or 16 later)
* SDR mode or DDR mode
* 

## High-Level Process View

This section will give a brief overview of the steps to process a PDM audio 
stream into a PCM audio stream. This section is concerned with the steady state
behavior and does not describe any necessary initialization steps.

### Step 1: PDM Capture

The PDM data signal is captured by the xcore.ai device's port hardware. The port
receiving the PDM data buffers the received samples. Each time the buffer is 
filled, the PDM rx Service (called "PDM rx") reads the received samples.

PDM rx, running either as an interrupt or as a dedicated thread, collects the 
samples word-by-word and assembles them into blocks of samples. Each time a full
block has been collected, the block is transferred to the decimator thread where
all remaining mic array processing takes place.

The size of PDM data blocks varies depending upon the configured number of 
microphone channels and the configured second stage decimator's decimation 
factor. Each PDM data block will contain exactly enough PDM samples to produce
one new output sample from the mic array.

### Step 2: First Stage Decimation

The conversion from the high-sample-rate PDM stream to lower-sample-rate PCM 
stream involves two stages of decimating filters. After the decimator thread 
receives (and deinterleaves) a block of PDM samples, the samples are filtered 
by the first stage decimator.

The first stage decimator has a fixed decimation factor of `32` and a fixed 
tap count of `256`. An application is free to supply its own filter coefficients 
for the first stage decimator (using the fixed decimation factor and tap count), 
however this library also provides a set of coefficients for the first stage
decimator that is recommended for most applications.

The first stage decimating filter is an FIR filter with 16-bit coefficients, and
where each input sample corresponds to a +1 or a -1 (typical for PDM signals). 
The output of the first stage decimator is a block of 32-bit samples with a 
sample time `32` times longer than the PDM sample time.

### Step 3: Second Stage Decimation

The second stage decimator is a decimating FIR filter with a configurable 
decimation factor and tap count. Like the first stage decimator, this library
provides a set of filter coefficients suitable for the second stage decimator.
The supplied filter has a tap count of `65` and a decimation factor of `6`.

The output of the first stage decimator is a block of `N * K` PCM values, where
`N` is the number of microphones and `K` is the second stage decimation factor.
This is just enough samples to produce one one output sample from the second
stage decimator.

The resulting sample is vector-valued (one element per channel) and has a sample 
time corresponding to `32 * K` PDM clock periods.

### Step 4: Post-Processing

After second stage decimation, the resulting sample goes to post-processing 
where two different post-processing behaviors are (explicitly) supported by this
library.

The first is a simple IIR filter, called DC Offset Elimination, which is 
intended to ensure each output (from the mic array module) channel tends to
approach zero mean. DC Offset Elimination can be disabled if not wanted.

The second major post-processing behavior is framing, where instead of signaling
each sample of audio to subsequent processing stages one at a time, samples can
be aggregated and transferred to subsequent processing stages as non-overlapping
blocks. The size of each frame is configurable (down to `1` sample per frame).

Finally, the sample or frame is transmitted over a channel from the mic array 
module to the next stage of the processing pipeline.

### Extending/Modifying Mic Array Behavior

It is worth noting that the core of the mic array library is several C++ class 
templates which are intended to be easily overridden for modified behavior. The
mic array component itself is an object made by the composition of several
smaller pieces which perform well-defined rolls.

For example, modifying the mic array to use some mechanism other than a channel
to move the audio frames out of the mic array is a matter of defining a small
new class encapsulating the behavior, and then instantiating the mic array class
template with your new class as the appropriate template parameter.

With that in mind, while most applications will have no need to modify the 
mic array behavior, it is nevertheless designed to be easy to modify.