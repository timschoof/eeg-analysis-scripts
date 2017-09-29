function epoch_corrected = baseline_correction(epoch, nSweeps, prestim, Fs)
%
% epoch = matrix of epoched EEG data
% nSweeps = number of sweeps or trials in the EEG data
% prestim = duration of the prestimulus baseline period (in seconds)
% Fs = sampling rate
%
% Version 1 - September 2017
%
% Tim Schoof - t.schoof@ucl.ac.uk
% -----------------------------------------

epoch_corrected = zeros((nSweeps),length(epoch(1,:))-round(prestim*Fs)+1);
for m = 1:nSweeps
    sweep = epoch(m,:);
    baseline = mean(sweep(1:round(prestim*Fs)));
    epoch_corrected(m,:) = sweep(round(prestim*Fs):length(sweep))-baseline;
end