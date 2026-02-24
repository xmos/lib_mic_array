:orphan:

# Basic Mic Array Example

## Hardware Required

- **XK-EVK-XU316-AIV.XN**

## Compile

```sh
cmake -G "Unix Makefiles" -B build
xmake -C build
```

## Run

```sh
xrun --xscope bin/app_mic_array.xe
```

## Convert Binary Data to WAV

```sh
python convert.py
```

**Output:**

```
Converted mic_array_output.bin to output.wav with 1 channels, 16000 Hz sample rate, and 32 bits per sample.
```
