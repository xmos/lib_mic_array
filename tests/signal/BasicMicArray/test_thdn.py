# Copyright 2022-2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

######
# Test: MicArray THDN test
#
# This test is intended to ensure that the THDN value of the mic array output is
# within the expected threshold
#
# This test does one thing in particular that may seem a bit suspect. Instead of
# reading PDM data from a port, the BasicMicArray is 'tricked' into using a
# streaming chanend as the resource that it reads the data from. Note that doing
# this does not require the BasicMicArray code to be modified in any way (which
# is good).
#
# It also makes the test much easier by evaporating the real-time constraint.
# But that does mean that this test case is in no way verifying that the
# BasicMicArray actually meets the real-time constraint.
#
# Notes:
#  - This test assumes that the CMake targets for this app are all already
#    built.
#  - This test directly launches xgdb, and so the XTC tools must be on your
#    path.
#  - An appropriate xCore device must be connected to the host using xTag
#  - This test should be executed with pytest. To run it, navigate to the root
#    of your CMake build directory, and run:
#       > pytest path/to/this/dir/test_thdn.py
######
import pytest
import numpy as np
from mic_array.pdm_signal import PdmSignal
from micarray_device import MicArrayDevice
from conftest import DevCommand
import json
from pathlib import Path
from thdncalculator import THDN
from mic_array_shared import MicArraySharedBase

with open(Path(__file__).parent / "test_params.json") as f:
  params = json.load(f)

def thdn_test_uncollect(config, fs, platform):
  level = config.getoption("level")
  if level == "smoke":
    if "xcore" in platform:
      return True # uncollect xcore run for smoke. Takes 2-3mins per test so run in nightly
  return False

class Test_BasicMicArray(MicArraySharedBase):

  @pytest.mark.uncollect_if(func=thdn_test_uncollect)
  @pytest.mark.parametrize("platform", ["python_only", "python_xcore"])
  @pytest.mark.parametrize("fs", params["SAMP_FREQ"], ids=[f"{s}" for s in params["SAMP_FREQ"]])
  def test_thdn(self, pytestconfig, request, fs, platform):
    chans = 2
    frame_size = 1
    use_isr = 1
    duration_s = 7
    freq_hz = {16000: [300, 7000], 32000: [300, 14000], 48000: [300, 20000]}
    thdn_threshold = {16000: [-123.0, -127.0], 32000: [-120.0, -121.0], 48000: [-108.0, -108.0]}

    custom_filter_file = None
    if not isinstance(fs, int): # fs must contain the name of the filter .pkl file
      custom_filter_file = fs
      cfg = f"{chans}ch_{frame_size}smp_{use_isr}isr_0mo_customfs"
    else:
      cfg = f"{chans}ch_{frame_size}smp_{use_isr}isr_0mo_{fs}fs"

    if custom_filter_file:
      filter = self.filter(Path(__file__).parent / f"{custom_filter_file}")
      pdm_freq = 3.072e6 # The final sampling rate calculation assumes PDM freq is 3.072MHz. Hardcoding
                         # since not stored in the filter class
      fs = int(pdm_freq / filter.DecimationFactor)
      assert fs in [16000, 32000, 48000], f"Error: fs {fs} for custom filter {custom_filter_file} not amongst the supported set [16000, 32000, 48000]"
    else:
      filter = self.filter(self.get_default_filter(fs))

    cwd = Path(request.fspath).parent

    xe_path = f'{cwd}/bin/{cfg}/test_ma_{cfg}.xe'
    assert Path(xe_path).exists(), f"Cannot find {xe_path}"

    print(f"duration: {duration_s}s, freqs: {freq_hz[fs]}, fs: {fs}, custom_filter_file: {custom_filter_file}")

    # Generate PDM input to mic_array
    sig_sine_pdm, sig_sine_pcm = PdmSignal.sine(freq_hz[fs], [0.52]*len(freq_hz[fs]), fs, duration_s)

    # Compute the expected output
    # Note: This assumes DCOE is disabled (which it should be in this app)
    expected = filter.Filter(sig_sine_pdm.signal)

    if self.print_output:
      print(f"Expected output: {expected}")

    if np.issubdtype(expected.dtype, np.integer):
      expected_output_float = expected.astype(np.float64)/np.iinfo(expected.dtype).max
    else:
      expected_output_float = expected

    for i in range(len(freq_hz[fs])):
      input_thdn = THDN(sig_sine_pcm[i], fs, fund_freq=freq_hz[fs][i])
      python_output_thdn = THDN(expected_output_float[i], fs, fund_freq=freq_hz[fs][i])
      print(f"python_output_thdn = {python_output_thdn}, input_thdn = {input_thdn}")
      assert python_output_thdn < thdn_threshold[fs][i], f"At sampling rate {fs}, freq {freq_hz[fs][i]}, Python output THDN {python_output_thdn} exceeds threshold {thdn_threshold[fs][i]}"

    if "xcore" in platform:
      # run on xcore only when not running smoke
      with MicArrayDevice(xe_path, quiet_xgdb=not self.print_xgdb, extra_xrun_args="--id 0") as dev:
        # Make sure we're talking to the correct application
        assert dev.param["channels"] == chans
        assert dev.param["s1.dec_factor"] == filter.s1.DecimationFactor
        assert dev.param["s1.tap_count"] == filter.s1.TapCount
        assert dev.param["s2.dec_factor"] == filter.s2.DecimationFactor
        assert dev.param["s2.tap_count"] == filter.s2.TapCount
        assert dev.param["frame_size"] == frame_size
        assert dev.param["use_isr"] == use_isr

        # If we're supposed to print filters, tell the device to do so
        if self.debug_print_filters:
          dev.send_command(DevCommand.PRINT_FILTERS.value)

        # Get the device's output
        device_output = dev.process_signal(sig_sine_pdm)
        if np.issubdtype(device_output.dtype, np.integer):
          device_output_float = device_output.astype(np.float64)/np.iinfo(device_output.dtype).max
        else:
          device_output_float = device_output

        for i in range(len(freq_hz[fs])):
          xcore_output_thdn = THDN(device_output_float[i][int(fs/10):], fs, fund_freq=freq_hz[fs][i])
          print(f"xcore_output_thdn = {xcore_output_thdn}")
          assert xcore_output_thdn < thdn_threshold[fs][i], f"At sampling rate {fs}, freq {freq_hz[fs][i]}, XCORE output THDN {xcore_output_thdn} exceeds threshold {thdn_threshold[fs][i]}"

        if self.print_output:
          print(f"Device output: {device_output}")

        dev.send_command(DevCommand.TERMINATE.value)

        # The second stage filter will usually yield exactly correct results, but
        # not always, because the 64-bit partial products of the inner product
        # (i.e.  filter_state[:] * filter_coef[:]) have a rounding-right-shift
        # applied to them prior to being summed.
        result_diff = np.max(np.abs(expected - device_output))
        threshold = 12
        print(f"result_diff = {result_diff}")
        assert result_diff <= threshold, f"max diff between python and xcore mic array output ({result_diff}) exceeds threshold ({threshold})"



  def thdn_test_OneStageFilter_uncollect(config, platform, decimator_stgs):
    level = config.getoption("level")
    if level == "smoke":
      if "xcore" in platform:
        return True # uncollect xcore run for smoke. Takes 2-3mins per test so run in nightly
    return False

  def to_float_array(self, x):
    """Convert integer array to float64 normalized to [-1, 1], or leave floats unchanged."""
    if np.issubdtype(x.dtype, np.integer):
      return x.astype(np.float64) / np.iinfo(x.dtype).max
    return x

  @pytest.mark.uncollect_if(func=thdn_test_OneStageFilter_uncollect)
  @pytest.mark.parametrize("platform", ["python_only", "python_xcore"])
  @pytest.mark.parametrize("decimator_stgs", [1], ids=["1stg"])
  def test_thdn_OneStageFilter(self, pytestconfig, request, platform, decimator_stgs):
    """Validate THD+N of the 1-stage filter path (768 kHz PDM -> 24 kHz PCM first stage decimator).

    Uses `small_768k_to_12k_filter_int.pkl` with only stage-1 decimation active.
    Tests a 2-channel 2-tone input and checks both Python reference and xcore outputs
    against per-tone THD+N thresholds. Also verifies sample-level diff between
    Python and xcore integer outputs within a fixed tolerance.
    """
    duration_s = 2 # running reduced duration. See https://github.com/xmos/lib_mic_array/issues/289
    pdm_freq = 768_000
    chans = 2
    freq_hz = [300, 5000]
    thdn_threshold = [-79.0, -76.0]

    cwd = Path(request.fspath).parent
    filter = self.filter(Path(__file__).parent / "small_768k_to_12k_filter_int.pkl")

    # --- num decimator stages dependent behaviour ---
    stg1_only = (decimator_stgs == 1)
    dec_factor = filter.s1.DecimationFactor if stg1_only else filter.DecimationFactor
    fs = int(pdm_freq / dec_factor)
    device_output_delay_samps = 0 if stg1_only else 1
    sample_override = duration_s * fs if stg1_only else None
    output_frame_size = 2 if stg1_only else 1
    print(f"decimator_stgs = {decimator_stgs}, fs = {fs}")
    # -------------------------------------------------

    cfg = f"{decimator_stgs}stg_filter"
    xe_path = f"{cwd}/bin/{cfg}/test_ma_{cfg}.xe"
    assert Path(xe_path).exists(), f"Cannot find {xe_path}"

    print(f"Test frequencies {freq_hz}\n")

    # Generate PDM input
    # Test one freq at a time since low-power mic array is mono
    sig_sine_pdm, sig_sine_pcm = PdmSignal.sine(
      freq_hz,
      [0.52]*len(freq_hz),
      fs,
      duration_s,
      fs_pdm=pdm_freq
    )

    print("Running python")
    expected = filter.Filter(sig_sine_pdm.signal, stg1_only=stg1_only)

    if self.print_output:
      print(f"Expected output: {expected}")

    expected_output_float = self.to_float_array(expected)

    for i in range(len(freq_hz)):
      input_thdn = THDN(sig_sine_pcm[i], fs, fund_freq=freq_hz[i])
      python_output_thdn = THDN(expected_output_float[i], fs, fund_freq=freq_hz[i])
      print(f"At fundamental freq {freq_hz[i]}, samp freq {fs}: python_output_thdn = {python_output_thdn}, input_thdn = {input_thdn}")
      assert python_output_thdn < thdn_threshold[i], (
          f"At sampling rate {fs}, freq {freq_hz[i]}, "
          f"Python output THDN {python_output_thdn} exceeds threshold {thdn_threshold[i]}"
      )

    if "xcore" in platform:
      print("Running xcore")
      with MicArrayDevice(xe_path, quiet_xgdb=not self.print_xgdb, extra_xrun_args="--id 0") as dev:
        assert dev.param["channels"] == chans
        assert dev.param["s1.dec_factor"] == filter.s1.DecimationFactor
        assert dev.param["s1.tap_count"] == filter.s1.TapCount
        assert dev.param["frame_size"] == output_frame_size
        assert dev.param["use_isr"] == 0

        if self.debug_print_filters:
          dev.send_command(DevCommand.PRINT_FILTERS.value)

        device_output = dev.process_signal(sig_sine_pdm, sample_count_override=sample_override)

        print(f"device_output shape: {device_output.shape}")

        device_output_float = self.to_float_array(device_output)

        for i in range(len(freq_hz)):
          xcore_output_thdn = THDN(device_output_float[i][int(fs/10):], fs, fund_freq=freq_hz[i])
          print(f"At fundamental freq {freq_hz[i]}, samp freq {fs}: xcore_output_thdn = {xcore_output_thdn}")
          assert xcore_output_thdn < thdn_threshold[i], f"At sampling rate {fs}, freq {freq_hz[i]}, XCORE output THDN {xcore_output_thdn} exceeds threshold {thdn_threshold[i]}"

        if self.print_output:
          print(f"Device output: {device_output}")

        dev.send_command(DevCommand.TERMINATE.value)

        end = -device_output_delay_samps or None
        start = device_output_delay_samps
        result_diff = np.max(np.abs(expected[:, :end] - device_output[:, start:]))
        threshold = 12
        print(f"result_diff = {result_diff}")
        assert result_diff <= threshold, (
          f"max diff between python and xcore mic array output ({result_diff}) "
          f"exceeds threshold ({threshold})"
        )