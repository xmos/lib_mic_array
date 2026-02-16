# Copyright 2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import numpy as np
import wave
import soundfile as sf


def convert_to_wav(
    input_file, output_file, num_channels=1, sample_rate=16000, bits_per_sample=32
):
    with open(input_file, "rb") as inp_f:
        data = inp_f.read()
        data = np.frombuffer(data, dtype=np.int32)
    
    sf.write(output_file, data, sample_rate, subtype='PCM_32')
    print(f"Converted {input_file} to {output_file} with {num_channels} channels, {sample_rate} Hz sample rate, and {bits_per_sample} bits per sample.")
    

if __name__ == "__main__":
    convert_to_wav(
        input_file="mic_array_output.bin",
        output_file="output.wav",
        num_channels=1,
        sample_rate=16000,
        bits_per_sample=32
    )
