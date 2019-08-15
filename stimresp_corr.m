function [LAG_ms, LAG_samp, maxmincor] = stimresp_corr(response, stimulus, epoch_dur, lagstart, lagstop, polarity)

% This function calculates the maximum correlation (maxmincor) value and its
% respective lag (LAG) over an imputted lag range, for a specified portion of a
% response file. The user must specify whether to find the max positive or max
% negative correlation value

% Description of function arguments:
% 1) response: response file (averaged and epoched, without any pre-stim)
% 2) stimulus: stimulus file (with the same sampling rate as the response file, on repetition of the stimulus without any zero padding) 
% 5) lagstart:   starting lag   (how much the File lags behind the
%                               Comparison)
% 6) lagstop:    stopping lag
% 7) polarity:   If 'POSITIVE', then find max positive correlation value
%                If 'NEGATIVE', then find max negative correlation value

% adapted from code written by: Erika Skoe - eeskoe@yahoo.com (2004)

%% Correlations
% Find out how many correlations to perform
latency = linspace(0, epoch_dur, length(response));
msPoints = latency(2)-latency(1);
totalLagPoints = round((lagstop-lagstart)/msPoints);
% Find start and stop points
startPt = interp1(latency,1:length(latency),lagstart,'nearest');
stopPt = length(stimulus)-1;

% Lag increases by msPoints each time through loop
for j = 1:totalLagPoints+1
    all_corrs(j,1) = nancorrcoef(response(startPt+(j-1):startPt+stopPt+(j-1)), stimulus);
    all_lags_samp(j,1) =  startPt + j-1;
    all_lags_ms(j,1) =  msPoints*(startPt + j-1);
end

% Find max pos/negative correlation
if strncmpi(polarity,'POSITIVE',3)==1
    % calculate the max positive correlation 
    maxmincor = max(all_corrs);
    [y, index] = max(all_corrs);
end

if strncmpi(polarity,'NEGATIVE',3)==1
    maxmincor = min(all_corrs);
    [y, index] = min(all_corrs);
end

%  calculate the LAG
LAG_ms = all_lags_ms(index,1); % lag in ms
LAG_samp = all_lags_samp(index,1); % lag in samples
