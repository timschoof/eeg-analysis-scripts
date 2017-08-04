function [WaveOut b a] = butter_filtfilt(WaveIn, Lcut_off, Hcut_off, order)
% Bandpass butterworth filter

Fs = 16384;

% Set Nyquist frequency to sample rate/2
Nyquist = Fs/2;
% normalise cut off frequency in range 0 to 1 relative to Nyquist frequency
Lnormalised_Fc = Lcut_off/Nyquist;
Hnormalised_Fc = Hcut_off/Nyquist;
normalFc = [Lnormalised_Fc Hnormalised_Fc];
% design butterworth filter
[b,a]=butter(order,normalFc, 'bandpass' );

% use filtfilt to lose phase distortion
% and apply filter coefficients to input signal 
[rows,cols] = size(WaveIn);
WaveIn = double(WaveIn);
for i = 1:rows
    WaveOut(i,:) = filtfilt(b,a,WaveIn(i,:));
end