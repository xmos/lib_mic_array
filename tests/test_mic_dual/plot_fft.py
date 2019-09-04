import numpy as np
import matplotlib.pyplot as plt
import scipy.fftpack
import scipy.stats
from scipy.signal import windows, welch
import soundfile as sf 
import sys


def plot_fft(in_file):
    audio_data, fs = sf.read(in_file)
    nyquist = fs // 2

    print(audio_data.shape)
    audio_len = audio_data.shape[0]

    x = np.linspace(0.0, fs, audio_len)
    y = audio_data

    w = windows.hann(audio_len)

    yf = scipy.fftpack.fft(y * w, n = 256 )
    fft_len = yf.shape[0]
    xf = np.linspace(0.0, fs, fft_len)

    yfn = np.abs(yf[:])[1:fft_len//2] / fft_len * np.sqrt(2)
    xfn = xf[1:fft_len//2]

    min_freq_flatness = 200
    max_freq_flatness = 6000

    #Only consider up to 7kHz to ignore transition band
    xfn_passband = xfn[xfn.shape[0] * min_freq_flatness // nyquist:xfn.shape[0] * max_freq_flatness // nyquist]
    yfn_passband = yfn[yfn.shape[0] * min_freq_flatness // nyquist:yfn.shape[0] * max_freq_flatness // nyquist]

    yfp = np.poly1d(np.polyfit(xfn_passband, yfn_passband, 10, full=False))
    print(yfp)

    print(xf.shape, yf.shape)

    rms = lambda array :np.sqrt(np.mean(array**2))

    print(rms(y))

    print(scipy.stats.describe(yfp(xfn_passband)))

    plt.subplot(3, 1, 1)
    plt.plot(x, y[:])
    plt.subplot(3, 1, 2)
    plt.plot(xfn, yfn)
    plt.subplot(3, 1, 3)
    plt.plot(xfn_passband, yfp(xfn_passband))
    plt.show()

def get_freq_peak(wav_file):
    audio_data, fs = sf.read(in_file)
    f, Pxx_spec = welch(audio_data, fs, 'flattop', 512, scaling='spectrum')
    # Ditch anything above 7.0kHz or below 100Hz
    idxs = np.where(f < 7000)
    idxs = np.where(f[idxs] > 100)

    yfp = np.poly1d(np.polyfit(f[idxs], np.sqrt(Pxx_spec[idxs]), 6, full=False))

    print(scipy.stats.describe(yfp(f[idxs])))

    plt.semilogy(f[idxs], np.sqrt(Pxx_spec[idxs]))
    plt.semilogy(f[idxs], yfp(f[idxs]))
    #plt.show()
#return f[np.argmax(Pxx_den)]

in_file = sys.argv[1]
#plot_fft(in_file)
get_freq_peak(in_file)
