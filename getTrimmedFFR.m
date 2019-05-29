function [outData, outTriggers] = getTrimmedFFR(EEGdata, nSamples,prestim, F0,F0x)

% This function does 4 main things:
%   opens up the appropriate mat file
%   extracts the recorded wave for nSamples from the single trigger
%   (optionally) resamples the wave so that its F0=128 Hz if it is not
%       already at that value. The script does not determine this itself -
%       that is specified in the function call. Default: no resampling

% prestim is in ms

% F0x gives the F0 as found in the original wave
% if it does not match the expected F0 Hz, the original wave is resampled

prestimSamples=(prestim/1000)*EEGdata.srate;

% turn
for k = 2:length(EEGdata.event)
    triggerLocation = EEGdata.event(:,k).latency;
    triggers = zeros(1,length(EEGdata.data));
    triggers(triggerLocation) = 1;
end

if F0x ~= F0
    % new rate
    xOld = EEGdata.data;
    NewSampFreq=F0*F0x;
    t=(0:length(EEGdata.data)-1)/EEGdata.srate;
    tNew=(0:1/NewSampFreq:max(t));
    EEGdata.data = interp1(t,xOld,tNew)';
    trigg = interp1(t,triggers,tNew,'next');
    % also need to find the new trigger point
    start = find(trigg);
    % need to adjust number of samples returned due
    % to different sampling frequency
    EEGdata.data = EEGdata.data(start+prestimSamples:start+prestimSamples+F0*floor(nSamples/F0x)-1);
    % save trigger in original format (i.e. coded as '255')
    EEGdata.event(:,2).latency = start;
else
    start = find(triggers);
    EEGdata.data = EEGdata.data(start+prestimSamples:start+prestimSamples+nSamples-1);
    % save trigger in original format (i.e. coded as '255')
    EEGdata.event(:,2).latency = 1;
end

outData = EEGdata.data;
outTriggers = EEGdata.event;
