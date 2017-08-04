function eeglab_ABR(fileDir, listener,Active, Reference, Lcut_off, Hcut_off, artifact,s_epoch, e_epoch, s_baseline, e_baseline)
% This script reads in 
% two channels
% assumes data is organised in folders for each participant separately


%% parameters
% fileDirectory - folder with files to be processed
% Active - active electrode (EXG1, EXG2, or EXG3)
% Reference - reference electrode (EXG2, EXG3, or EXG4)
% Lcut_off - lower bound bandpass filter
% Hcut_off - upper bound bandpass filter
% s_epoch - start time (in ms) of epoch
% e_epoch - end time (in ms) of epoch
% s_baseline - start time (in ms) of pre-stim
% e_baseline - end time (in ms) of pre-stim

%% Version
% Version 1.0 - June 2012
%       Based on EEGLAB history file generated on the 04-Jun-2012
%   Assumes a 32-set of empty electrode is imported. EXG electrodes start at 33.
%
% Version 1.1 - June 2012
%       Extracts only the active and reference channels. Only works with 2
%       channels.
%       Also changed pop_biosig
%
% Version 1.2 - March 2013
%     Can read in files from other directories (no longer necessary to copy BDF files into eeglab folder)
%     Still writes output files into eeglab folder
%
% Version 2 - August 2017
%   MATLAB version: R2016a
%   EEGLAB version: eeglab14_1_1b
%
% Tim Schoof - t.schoof@ucl.ac.uk
% ------------------------------------------------

%% some starting values
order = 2; % butterworth filter order

% specify file directory - assumes data for every participant is in a
% separate subfolder within the specified file directory
fileDirectory = [fileDir '\' listener];
% get a list of BDF files
Files = dir(fullfile(fileDirectory, '*.bdf'));
nFiles = size(Files);

% create output directory within main file directory
OutputDir = [fileDir '\' 'EEGlab Output' ];
mkdir(OutputDir)

% create output file for number of rejected and accepted sweeps
OutFile = [OutputDir '\' listener  '_rejected_sweeps' '.csv'];
% write some headings and preliminary information to the output file
WriteHeader = exist(OutFile);
fTrackOut = fopen(OutFile, 'at');
if ~WriteHeader
    fprintf(fTrackOut, 'listener,response,accepted,rejected');
    fclose(fTrackOut);
end

%% loop through all the files in the directory
for i=1:nFiles
    fileName = Files(i).name;
    [pathstr, name, ext] = fileparts(fileName);
    
    % specify active channel
    if strcmp(Active, 'EXG1')
        Act = 33;
    elseif strcmp(Active, 'EXG2')
        Act = 34;
    elseif strcmp(Active, 'EXG3')
        Act = 35;
    elseif strcmp(Active, 'A32')
        Act = 32;
    else
        error('ERROR: Your active electrode should be EXG1, EXG2, EXG3, or A32')
    end
    
    % specify reference channel
    if strcmp(Reference, 'EXG1')
        Ref = 33;
    elseif strcmp(Reference,'EXG2')
        Ref = 34;
    elseif strcmp(Reference, 'EXG3')
        Ref = 35;
    elseif strcmp(Reference, 'EXG4')
        Ref = 36;
    elseif strcmp(Reference, 'EXG3+4')
        Ref = [35 36];
    else
        error('ERROR: Your reference electrode should be EXG2, EXG3, EXG4, or EXG3+4')
    end
    
    % recodes reference channel for re-referencing
    if Act == Ref
        error('ERROR: Your reference electrode and active electrode cannot be the same')
    elseif Act < Ref
        reref = 2;
    elseif Act > Ref
        reref = 1;
    end
    
    % start eeglab
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
    
    % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
    EEG = pop_biosig((fullfile(fileDirectory,fileName)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
    [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    EEG = eeg_checkset( EEG );
    
    % filter based on filtfilt (so effectively zero phase shift)
    fprintf('%s', 'Filtering...')
    EEG.data = butter_filtfilt(EEG.data, Lcut_off, Hcut_off, order);
    
    % epoch
    % convert epoch start and end times to seconds
    s_epoch_s = s_epoch/1000;
    e_epoch_s = e_epoch/1000;
    % epoch
    totalsweeps = length(EEG.event)-2;
    epoch = zeros((totalsweeps),round((e_epoch_s-s_epoch_s)*EEG.srate));
    for n = 1:totalsweeps
        epoch(n,:) = EEG.data(EEG.event(n+1).latency:EEG.event(n+1).latency+round((e_epoch_s-s_epoch_s)*EEG.srate)-1);
    end
         
    % baseline correction
    epoch_corrected = zeros((totalsweeps),length(epoch(1,:))-round((e_baseline/1000)*EEG.srate)+1);
    for m = 1:totalsweeps
        sweep = epoch(m,:);
        baseline = mean(sweep(round((s_baseline/1000)*EEG.srate):round((e_baseline/1000)*EEG.srate)));
        epoch_corrected(m,:) = sweep(round((e_baseline/1000)*EEG.srate):length(sweep))-baseline;
    end
    
    % artifact rejection
    countr = 1;
    for nn = 1:(totalsweeps)
        if (max(epoch_corrected(nn,:))>artifact) || (min(epoch_corrected(nn,:))< -1*artifact)
            rm_index(countr) = nn;
            countr = countr+1;
        end
    end
    % remove trials
    if exist('rm_index')
        epoch([rm_index],:) = [];
        rejected = length(rm_index);
        accepted = totalsweeps - rejected;
    else
        rejected = 0;
        accepted = totalsweeps;
    end
    
    % average across draws
    avg = mean(epoch_corrected,1);

    % plot averaged response
    figure('color','white')
    s = (length(avg)/EEG.srate)*1000;
    t = (0:(s/(length(avg)-1)):s);
    p = plot(t,avg);
    set(0, 'DefaulttextInterpreter', 'none')
    title(['', name, '']);
    xlabel('ms');
    ylabel('uV')
    set(p, 'Color', 'Black');
    % save figure
    saveas(gcf,['', OutputDir, '\', name, '_average', ''],'fig');
    
    % save averaged EEG mat files
    % select correct channel
    % write to txt and avg
    save(['', OutputDir, '\', name, '_average.mat', ''],'avg');
    
    % print out relevant information to csv file
    fTrackOut = fopen(OutFile, 'at');
    fprintf(fTrackOut, '\n%s,%s,%d,%d', ...
        OutputDir,name,accepted,rejected);
    fclose(fTrackOut);
    
    % clear all
    clear ALLCOM ALLEEG CURRENTSET CURRENTSTUDY EEG LASTCOM STUDY rm_index
end

fprintf('%s', 'Finished!')

clear all
close all
