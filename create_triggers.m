function [triggerField, nTrigs] = create_triggers(EEGdata, nTrigs, trigTiming, startSweep, endSweep, s_epoch_s,e_epoch_s, prestim)
%
% The rapid FFR is typically recorded using only a single trigger at the start
% (and possibly another one at the end) of the recording. This is to avoid
% any potential trigger artefacts in the recordings. In order to epoch the
% data (e.g. across a single F0 cycle), a new trigger field needs to be
% created.
%
% This script creates a string of triggers either 'phaselocked' to the response 
% (giving you the signal) or placed in a 'random' fashion (giving you the noise floor) 
%
% EEGdata = EEG data structure (including field with rigger locations)
% nTrigs = number of triggers to be created
% trigTiming = the timing or location of the triggers: 'phaselocked', 'random'
% startSweep = starting point for the triggers (this can either be the
% first trigger, or if the interest is in analysing chunks of the EEG
% signal it can also be a later start point)
% endSweep = end point for the triggers (this can either be the
% last trigger, or if the interest is in analysing chunks of the EEG
% signal it can something else)
% s_epoch_s = start time of an epoch (in seconds), used to compute
% inter-trigger interval
% e_epoch_s = end time of an epoch (in seconds), used to compute
% inter-trigger interval
% prestim = duration of the prestimulus silence (in seconds)
% 
% Version 1 - September 2017
%
% Tim Schoof - t.schoof@ucl.ac.uk
% ----------------------------------------

% determine trigger interval
s_trig_interval = round((e_epoch_s-s_epoch_s)*EEGdata.srate);
            
% determine timing of first and last trigger point
startTrig = EEGdata.event(1,2).latency + round((prestim)*EEGdata.srate) + ((startSweep+1)*s_trig_interval); % don't look at first 2 nReps
endTrig = EEGdata.event(1,2).latency + round((prestim)*EEGdata.srate) + ((endSweep-1)*s_trig_interval); % don't look at final nRep

if strcmp(trigTiming,'random')
    % create randomly placed triggers (this likely results in overlapping
    % epochs)
    triggers = round((endTrig-startTrig).*rand(1,nTrigs)+startTrig);
    triggers = sort(triggers);
elseif strcmp(trigTiming,'phaselocked')
    % create triggers phaselocked to the response (i.e. evenly spaced at a
    % given interval)
    triggers = [startTrig:s_trig_interval:endTrig];
end

%% replace trigger field
for i = 1:length(triggers)
    if i == 1
        % remove EEG.event field, will be replaced below
        EEGdata = rmfield(EEGdata, 'event'); 
    end
    % create new EEG.event field with the newly generated trigger locations
    EEGdata.event(1,i) = struct('type',255,'latency',triggers(i),'urevent',i);
end

% extract trigger field to pass to main function
triggerField = EEGdata.event;