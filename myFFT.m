function [fftFFR, HzScale] = myFFT(data,Fs,fileName)
%
% Compute and plot FFT
%
% Version 1 - September 2017
%
% Tim Schoof - t.schoof@ucl.ac.uk
% ----------------------------------

% compute FFT
L=length(data);
NFFT = 2^nextpow2(L); % Next power of 2 from length of y
Y = fft(data,NFFT)/L;
f = Fs/2*linspace(0,1,NFFT/2+1);
fftFFR = 2*abs(Y(1:NFFT/2+1));
HzScale = [0:(Fs/2)/(length(fftFFR)-1):round(Fs/2)]'; % frequency 'axis'

% plot FFT
plot(HzScale,fftFFR,'LineWidth',4)
axis([0 1200 0 500])
set(0, 'DefaulttextInterpreter', 'none')
title(['',fileName,''])
xlabel('Spectral magnitude')
ylabel('Frequency (Hz)')