pkg load signal

clear all

#first stage
fs = 3072;
bw = fs/2;
b = 64; 
nulls = (fs)/8;
f = [0 b/bw (nulls*1-b)/bw, (nulls*1+b)/bw  (nulls*2-b)/bw, (nulls*2+b)/bw  (nulls*3-b)/bw, (nulls*3+b)/bw  (nulls*4-b)/bw, 1.0 ];
a = [1 1 0 0 0 0 0 0 0 0 ];
first_h = remez(8*6 - 1 , f, a, [0.00002, 1, 1, 1, 1]);
[h1, w1] = freqz(first_h, 1, 2^16, 3072000);
subplot(2, 3, 1);
plot(w1,20*log10(abs(h1)),'b');
title('First FIR')

#second stage - divide by 4
fs = 384;
bw = fs/2;
b = 16;
nulls = (fs)/4;
f = [0 b/bw (nulls*1-b)/bw, (nulls*1+b)/bw  (nulls*2-b)/bw,  1.0 ];
a = [1 1 0 0 0 0 ];
second_h = remez(15 , f, a, [0.00006731, 1, 1]);#this weight is tuned for sum of 1.0000
[h1, w1] = freqz(second_h, 1, 65536, 384000);
subplot(2, 3, 2);
plot(w1,20*log10(abs(h1)),'b');
title('Second FIR')

#TODO
#take magnitude response between 0 and 96000/(2*n) for above firs and multiply them then compensate 
#for them in the final stage fir for each n in 1..8

#48KHz output
third_48_h = remez(32*2*1-1, [0, 19/48 26/48 1], [1, 1, 0, 0], [.0002, 1]);
[h1, w1] = freqz(third_48_h, 1, 65536, 384000);
subplot(2, 3, 3);
plot(w1,20*log10(abs(h1)),'b');
title('48kHz FIR')

#24KHz output 
third_24_h = remez(32*2*2-1, [0, 10.4/48 12.8/48 1], [1, 1, 0, 0], [.0001, 1]);
[h1, w1] = freqz(third_24_h, 1, 65536, 384000);
subplot(2, 3, 4);
plot(w1,20*log10(abs(h1)),'b');
title('24kHz FIR')

#16KHz output
third_16_h = remez(32*2*3-1, [0, 7.1/48 8.6/48 1], [1, 1, 0, 0], [.0001, 1]);
[h1, w1] = freqz(third_16_h, 1, 65536, 384000);
subplot(2, 3, 5);
plot(w1,20*log10(abs(h1)),'b');
title('16kHz FIR')

#12KHz output
third_12_h = remez(32*2*4-1, [0, 5/48 6.1/48 1], [1, 1, 0, 0], [.0001, 1]);
[h1, w1] = freqz(third_12_h, 1, 65536, 384000);
subplot(2, 3, 6);
plot(w1,20*log10(abs(h1)),'b');
title('12kHz FIR')

#8KHz output
third_8_h = remez(32*2*6-1, [0, 3.5/48 4.2/48 1], [1, 1, 0, 0], [.0001, 1]);
[h1, w1] = freqz(third_8_h, 1, 65536, 384000);
subplot(2, 3, 6);
plot(w1,20*log10(abs(h1)),'b');
title('8kHz FIR')

dlmwrite("first_h.txt", first_h);
dlmwrite("second_h.txt", second_h);
dlmwrite("third_48_h.txt", third_48_h);
dlmwrite("third_24_h.txt", third_24_h);
dlmwrite("third_16_h.txt", third_16_h);
dlmwrite("third_12_h.txt", third_12_h);
dlmwrite("third_8_h.txt", third_8_h);
