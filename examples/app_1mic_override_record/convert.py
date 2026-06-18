# Copyright 2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import argparse
import numpy as np
import soundfile as sf


def convert_to_wav(
    input_file, output_file, num_channels=1, sample_rate=16000, bits_per_sample=32
):
    with open(input_file, "rb") as inp_f:
        data = np.frombuffer(inp_f.read(), dtype=np.int32)

    if num_channels > 1:
        # Interleaved layout: [ch0_s0, ch1_s0, ch0_s1, ch1_s1, ...]
        # Reshape to [n_samples, n_channels] as expected by soundfile
        data = data.reshape(-1, num_channels)

    sf.write(output_file, data, sample_rate, subtype='PCM_32')
    print(f"Converted {input_file} to {output_file} with {num_channels} channel(s), "
          f"{sample_rate} Hz sample rate, and {bits_per_sample} bits per sample.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert raw PCM binary to WAV.")
    parser.add_argument("--input",    default="mic_array_output.bin", help="Input binary file")
    parser.add_argument("--output",   default="output.wav",           help="Output WAV file")
    parser.add_argument("--channels", default=2,   type=int,          help="Number of channels (default: 1)")
    parser.add_argument("--rate",     default=16000, type=int,        help="Sample rate in Hz (default: 16000)")
    parser.add_argument("--bits",     default=32,  type=int,          help="Bits per sample (default: 32)")
    args = parser.parse_args()

    convert_to_wav(
        input_file=args.input,
        output_file=args.output,
        num_channels=args.channels,
        sample_rate=args.rate,
        bits_per_sample=args.bits,
    )
