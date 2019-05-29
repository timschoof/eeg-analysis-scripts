function epoch = epochEEG(EEGdata,nSweeps,s_epoch_s,e_epoch_s,replacement)
%
% This script epochs EEG data, using sampling with or without replacement.
%
% EEGdata = EEG data structure (including data to be epoched and trigger locations)
% nSweeps = number of trials or sweeps to be epoched
% replacement = sampling 'with' or 'without' replacement
%
% Version 1 - September 2017
%
% Tim Schoof - t.schoof@ucl.ac.uk
% ----------------------------------------

%% make sure the data is long enough for the number of planned epochs
if length(EEGdata.event) < nSweeps
    nSweeps = length(EEGdata.event);
end

sweepLength = round((e_epoch_s-s_epoch_s)*EEGdata.srate);
epoch=zeros((nSweeps),sweepLength);

%% loop through the number of sweeps to be epoched
for n = 2:nSweeps+1
    % sample with or without replacement
    if strcmp(replacement,'with') % with replacement
        perm = randperm(nSweeps);
        perm = perm(1);
    elseif strcmp(replacement,'without') % without replacement
        perm = n;
    end
    % determine starting point of the epoch
    startLat = round(EEGdata.event(1,perm).latency+(s_epoch_s*EEGdata.srate));
    % epoch
    epoch(n-1,:) = EEGdata.data(startLat:startLat+sweepLength-1);
end
