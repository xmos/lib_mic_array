
# Software Structure

The core of `lib_mic_array` are a set of C++ class templates representing the
mic array and its sub-components. 

The template parameters of these class templates are (mainly) used for two 
different purposes. Non-type template parameters are used to specify certain
quantitative configuration values, like the number of microphone channels or
the second stage decimator tap count. Type template parameters, on the other 
hand, are used for configuring the behavior of sub-components.

## High-Level View

At the heart of the mic array API is the `MicArray` class template.

> **Aside:** All classes and class templates mentioned are in the `mic_array` 
C++ namespace unless otherwise specified. Additionally, this documentation may 
refer to _class templates_ (e.g. `MicArray`) as _classes_ when doing so is 
unlikely to lead to confusion.

The `MicArray` class template looks like the following:

```c++
  template <unsigned MIC_COUNT,
            class TDecimator,
            class TPdmRx, 
            class TSampleFilter, 
            class TOutputHandler> 
  class MicArray;
```

Here the non-type template parameter `MIC_COUNT` indicates the number of 
microphone channels to be captures and processed by the mic array component.
_Most of the class templates have this as a parameter_.

A `MicArray` object comprises 4 sub-components:

| Member Field    | Component Class       | Responsibility |
|-----------------|-----------------------|----------------|
| `Decimator`     | `TDecimator`          | 2-stage decimation on blocks of PDM data
| `PdmRx`         | `TPdmRx`              | Capture of PDM data from a port
| `SampleFilter`  | `TSampleFilter`       | Post-processing of decimated samples
| `OutputHandler` | `TOutputHandler`      | Transferring audio data to subsequent pipeline stages.

Each of `MicArray`'s sub-components has a type that is specified as a template 
parameter when the class template is instantiated. `MicArray` requires the 
class of each of its sub-components to implement an interface. The `MicArray`
object interacts with its sub-components using this interface.

> **Aside:** Abstract classes are **not** used to enforce this interface 
contract. Instead, the contract is enforced (at compile time) solely in how the 
`MicArray` object makes use of the sub-component.

_Why use template parameters instead of polymorphism?_ Similar functionality may
have been achieved by defining abstract classes representing each sub-component 
instead. There are several drawbacks to using polymorphism to achieve this
behavior, but the major issues are that using polymorphism prevents much
compile-time optimization and static analysis (e.g. stack requirements). 

For example, the `NopSampleFilter` class template is a sample filter which does 
nothing to the samples. If polymorphism were used, the call to 
`NopSampleFilter::Filter()` can't be avoided. Using the class template, however,
the compiler can completely optimize out this call when `NopSampleFilter` is
used. In other cases, calls may be inlined into the calling function.

The following diagram conceptually captures the flow of information through the
`MicArray` sub-components.

              xCore Port
      ____________v_________________________________________
     |            |         MicArray                        |
     |    PDM     |     _________________                   |
     |    Samples |    |                 |                  |
     |            `--->|  PdmRx          |---.              |
     |                 |_________________|   |              |
     |                  _________________    | PDM Sample   |
     |                 |                 |   | Blocks       |
     |             .---|  Decimator      |<--`              |
     |             |   |_________________|                  |
     |   Decimated |    _________________                   |
     |   Sample    |   |                 |                  |
     |             `-->|  SampleFilter   |---.              |
     |                 |_________________|   |              |
     |                  _________________    | Filtered     |
     |                 |                 |   | Sample       |
     |             .---|  OutputHandler  |<--`              |
     |    Sample   |   |_________________|                  |
     |    or Frame |                                        |
     |_____________|________________________________________|
                   v
              xCore Channel


> **Note:** `MicArray` does not enforce the use of an xCore `port` for 
collecting PDM samples or an xCore `channel` for transferring processed data. 
This is just the typical usage.

### Mic Array / Decimator Thread

Aside from aggregating its sub-components into a single logical entity, the
`MicArray` class template also holds the high-level logic for capturing, 
processing and transfering the audio stream data.

The following code snippet is the implementation for the main mic array thread
(also referred to throughout the documentation as the "decimator thread", to
distinguish it from the (optional) PDM capture thread.

```c++
void mic_array::MicArray<MIC_COUNT,TDecimator,TPdmRx,
                                   TSampleFilter,
                                   TOutputHandler>::ThreadEntry() {
  int32_t sample_out[MIC_COUNT] = {0};

  while(1){
    uint32_t* pdm_samples = PdmRx.GetPdmBlock();
    Decimator.ProcessBlock(sample_out, pdm_samples);
    SampleFilter.Filter(sample_out);
    OutputHandler.OutputSample(sample_out);
  }
}
```

The thread loops forever, and on each iteration

* _Requests a block of PDM sample data the PDM rx service._ This is a blocking 
call which only returns once a complete block becomes available.

* _Passes the block of PDM sample data to the decimator to produce a single 
output sample._

* _Applies a post-processing filter to the sample data._

* _Passes the processed sample to the output handler to be transferred to the 
next stage of the processing pipeline_. This may also be a blocking call, only
returning once the data has been transferred.

Note that the `MicArray` object doesn't care how these steps are actually
implemented. For example, one output handler implementation may send samples
one at a time over a channel. Another output handler implementation may collect
samples into frames, and use a FreeRTOS queue to transfer the data to another
thread.

### Sub-Component Initialization

Each of `MicArray`'s sub-components may have implementation-specific 
configuration or initialization requirements. Each sub-component is a `public`
member of `MicArray` (see table above). An application can access a 
sub-component directly to perform any type-specific initialization or other
manipulation.

For example, the `ChannelSampleTransmitter` output handler class needs to know
the `chanend` to be used for sending samples. This can be initialized on a 
`MicArray` object `mics` with `mics.OutputHandler.SetChannel(c_sample_out)`.


## Sub-Components

This section gives a more detailed look at each of `MicArray`'s sub-components.

### PdmRx

`PdmRx`, or the PDM rx service is the `MicArray` sub-component responsible for
capturing PDM sample data, assembling it into blocks, and passing it along so
that it can be decimated.

The `MicArray` class requires only that `PdmRx` implement `GetPdmBlock()`, a 
blocking call that returns a pointer to a block of PDM data which is ready for 
further processing.

Generally speaking, `PdmRx` will derive from the `PdmRxService` class template.
`PdmRxService` encapsulates the logic of using an xCore `port` for capturing
PDM samples one word (32 bits) at a time, and managing two buffers where blocks
of samples are collected. It also simplifies the logic of running PDM rx as 
either an interrupt or as a stand-alone thread.

`PdmRxService` has 2 template parameters. The first template parameter is the 
`BLOCK_SIZE`, which specifies the size of a PDM sample block (in words). The
second template parameter, `SubType` is the type of the sub-class being derived
from `PdmRxService. This is the CRTP (Curiously Recurring Template Pattern),
which allows base class to use polymorphic-like behaviors while ensuring that 
all types are known at compile-time, avoiding the drawbacks of using virtual
functions.

There is currently one class template which derives from `PdmRxService`, called
`StandardPdmRxService`. `StandardPdmRxService` uses a streaming channel to
transfer PDM blocks to the decimator. It also provides methods for installing
an optimized ISR for PDM capture.

### Decimator

The `Decimator` sub-component encapsulates the logic of converting blocks of PDM 
samples into PCM samples. The `TwoStageDecimator` class is a decimator 
implementation that uses a pair of decimating FIR filters to accomplish this.

The first stage has a fixed tap count of `256` and a fixed decimation factor of
`32`. The second stage has a configurable tap count and decimation factor.

### SampleFilter

The `SampleFilter` sub-component is used for post-processing samples emitted by
the decimator. Two implementations for the sample filter sub-component are 
provided by this library.

The `NopSampleFilter` class can be used to effectively disable per-sample 
filtering on the output of the decimator. It does nothing to the samples 
presented to it, and so calls to it can be optimized out during compilation.

The `DcoeSampleFilter` class is used for applying the DC offset elimination
filter to the decimator's output. The DC offset elimination filter is meant to
ensure the sample mean for each channel tends toward zero.

### OutputHandler

The `OutputHandler` sub-component is responsible for transferring processed
sample data to subsequent processing stages.

There are two main considerations for output handlers. The first is whether 
audio data should be transferred _sample-by-sample_ or as _frames_ containing
many samples. The second is the method of actually transferring the audio data.

The class `ChannelSampleTransmitter` sends samples one at a time to subsequent
processing stages using an xCore channel.

The `FrameOutputHandler` class collects samples into frames, and uses a
frame transmitter to send the frames once they're ready.

## Prefabs

One of the drawbacks to broad use of class templates is that concrete class
names can unfortunately become (excessively) verbose. For example, the following
is the fully qualified name of a concrete `MicArray` implementation:

```cpp
mic_array::MicArray<2,  
    mic_array::TwoStageDecimator<2,6,65>, 
    mic_array::StandardPdmRxService<2*6>, 
    mic_array::DcoeSampleFilter<2>, 
    mic_array::FrameOutputHandler<2,256,
        mic_array::ChannelFrameTransmitter>>
```

This library also provides a C++ namespace `mic_array::prefab` which is intended
to simplify construction of `MicArray` objects where common configurations are
needed.

The `mic_array::prefab::BasicMicArray` class template uses the most typical
component implementations, where PDM rx can be run as an interrupt or as a
stand-alone thread, and where audio frames are transmitted to subsequent 
processing stages using a channel.

To demonstrate how `BasicMicArray` simplifies this process, observe that the
following `MicArray` type is behaviorally identical to the above:

```cpp
mic_array::prefab::BasicMicArray<2,256,true>
```
