function [newData, newTriggers, newCycles] =  whatF0(data,fileName, OutputDir, F0, prestim, nCycles)
% The first task is to determine the actual F0 of the recorded wave
% The second task is to resample the wave so that the F0 is actually 128 Hz
%
% function x = getTrimmedFFR(fileName, nSamples, F0x)
% (see top of function for information)

% construct the output data file name
outfile = ['', OutputDir,'\unadjusted_F0.csv', ''];
% write some headings and preliminary information to the output file
if ~exist(outfile)
    fout = fopen(outfile, 'at');
    fprintf(fout, 'file,F0\n');
    fclose(fout);
end

%%
% reset some starting values
periodInSamples = data.srate/F0;
nSamples = nCycles * periodInSamples;

[ffr, data.event] = getTrimmedFFR(data,nSamples,prestim,F0,F0);

% do the largest FFT which is a whole number of cycles
% making this 600 leads to 512 cycles analyzed
maxCycles=nCycles;
% it could be that there is no real point in ensuring this FFT is
% calculated over a power of 2. I understand there is not much of a penalty
% for lengths that are not powers of 2, but it should definitely include a
% whole number of cycles.
NFFT = 2^(nextpow2(maxCycles*periodInSamples)-1);
[f, HzScale, dB] = myFFT(ffr(1:NFFT),data.srate,0);

% Now select out the part of the spectrum around 128 Hz: see readOuts() for
% further documentation
fftRegion = readOuts(F0,HzScale, dB, 5);
% find the peak in this region, and extract the frequency value
F0x = fftRegion(max(fftRegion(:,3))==fftRegion(:,3),2);

% save away unadjusted F0
fout = fopen(outfile, 'at');
fprintf(fout, '%s,%5.4f\n', ...
    fileName,F0x);
fclose(fout);

% plot the spectrum to verify the extracted frequency value is correct
% (and not just noise)
figure
plot(HzScale,dB)
title(['',fileName,''])
saveas(gcf,['',OutputDir,'\',fileName,'_', num2str(F0) ,'Hz_FFT_beforeAdjustedF0.fig',''])

% % In theory, you could get a more accurate estimate by measuring a higher
% % harmonic and dividing through. Here is for the 7th harmonic
% vv896 = readOuts(896, f, dB, 20);
% vv896(max(vv896(:,3))==vv896(:,3),2)/7
% % Which turns out exactly the same. Maybe there is some basic property of
% % the FFT I am not considering. However you get it, this is your magic
% % number! I think the crucial thing is to ensure this same number arises
% % out of every recording. It might be safer to only look for the F0

% Once you know the actual F0, the rest is easy! Here getTrimmedFFR() is
% being used to resample the wave, and extract the appropriate
% section. The position of the trigger is recalculated, and fewer samples
% are taken to account for the fact that the new sampling frequency is
% slightly higher.
nCycles = 7500; % 67497; % I figured this out directly rather than writing an equation
nSamples = nCycles * periodInSamples;
ffr = getTrimmedFFR(data, nSamples,prestim, F0, F0x);
% This should now have F0=128. Let's check.
maxCycles=nCycles;
NFFT = 2^(nextpow2(maxCycles*periodInSamples)-1);
[f, HzScale, dB] = myFFT(ffr(1:NFFT),data.srate,0);
fftRegion = readOuts(F0, HzScale, dB, 5);
F0x2 = fftRegion(max(fftRegion(:,3))==fftRegion(:,3),2);

if F0x2 == F0
    % trimmed and resampled ffr with the correct F0
    newData = ffr(:,1);
    newTriggers = ffr(:,2);
    newCycles = nCycles;
else
    error(['','F0 has not been changed to ', num2str(F0) ,' Hz',''])
end

