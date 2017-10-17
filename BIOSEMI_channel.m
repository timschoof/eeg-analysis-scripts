function [Act, Ref, reref] = BIOSEMI_channel(Active, Reference)
%
% Recodes active and reference channels from channel ID (e.g. EXG1) to
% channel number (e.g. 33)
%
% Only works when you want to read in two EEG channels (active and
% reference) at the moment.
%
% Version 1 - September 2017
%
% Tim Schoof - t.schoof@ucl.ac.uk
% ------------------------------------------------

%% specify active channel
if strcmp(Active, 'EXG1')
    Act = 33;
elseif strcmp(Active, 'EXG2')
    Act = 34;
elseif strcmp(Active, 'EXG3')
    Act = 35;
elseif strcmp(Active, 'A32')
    Act = 32;
elseif strcmp(Active,'EXG5')
    Act = 37;
else
    error('ERROR: Your active electrode should be EXG1, EXG2, or EXG3')
end

%% specify reference channel
if strcmp(Reference, 'EXG1')
    Ref = 33;
elseif strcmp(Reference,'EXG2')
    Ref = 34;
elseif strcmp(Reference, 'EXG3')
    Ref = 35;
elseif strcmp(Reference, 'EXG4')
    Ref = 36;
elseif strcmp(Reference, 'EXG5')
    Ref = 37;
elseif strcmp(Reference, 'EXG1+2')
    Ref = [33 34];
elseif strcmp(Reference, 'EXG3+4')
    Ref = [35 36];
else
    error('ERROR: Your reference electrode should be EXG1, EXG2, EXG3, EXG4, or EXG5')
end

%% recodes reference channel for re-referencing
if Act == Ref
    error('ERROR: Your reference electrode and active electrode cannot be the same')
elseif Ref(1) == 33 && Ref(2) == 34 && Act < Ref(1)
    reref = [2 3];
elseif Ref(1) == 33 && Ref(2) == 34 && Act > Ref(1)
    reref = [1 2];
elseif Ref(1) == 35 && Ref(2) == 36 && Act < Ref(1)
    reref = [2 3];
elseif Ref(1) == 35 && Ref(2) == 36 && Act > Ref(1)
    reref = [1 2];
elseif Act < Ref
    reref = 2;
elseif Act > Ref
    reref = 1;
end