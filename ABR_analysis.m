function ABR_analysis(fileDir, listener,Active, Reference,epoch_dur, prestim, Lcut_off, Hcut_off, artefact)
% Click ABR analysis script
% Only reads in two or three channels.
% Assumes data is organised in folders for each participant separately.

%% parameters
% fileDirectory - folder with files to be processed
% Active - active electrode (EXG1, EXG2, or EXG3)
% Reference - reference electrode (EXG2, EXG3, or EXG4)
% considered artefacts and removed from the set of epochs
% epoch_dur - duration (in ms) of epoch (excluding the prestim)
% prestim - duration of the baseline (i.e. end time (in ms) of pre-stim)
% Lcut_off - lower bound bandpass filter
% Hcut_off - upper bound bandpass filter
% artefact - epochs containing values exceeding +/- this value (in uV) are

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
%   Script no longer relies heavily on eeglab - only uses it to read in BDF
%   file and re-reference the data.
%
% Version 2.2 - October 2017
%   Plot gray shaded area around the response representing the standard
%   error of the mean (SEM)
%
% Dependencies:
%  * eeglab
%  * baseline_correction.m
%  * BIOSEMI_channel.m
%  * create_triggers.m
%  * butter_filtfilt.m
%  * epochEEG.m
%  * myFFT.m
%  * rejectArtefacts.m
%
%   MATLAB version: R2016a
%   EEGLAB version: eeglab14_1_1b
%
% Tim Schoof - t.schoof@ucl.ac.uk
% ------------------------------------------------

%% some starting values
order = 2; % butterworth filter order
tube_delay = 1; % time it takes for sound to travel along the tubing of the insert earphones (in ms), this is added to the prestim (measured 4 July 2018)
trigger_artefact_window = 2; % period affected by trigger artefact (in ms), this is excluded from the baseline and epoch

% if certain arguments are not specified, set them to their default value
if nargin<9
    artefact = 25;
end
if nargin<8
    Hcut_off = 3000;
end
if nargin<7
    Lcut_off = 100;
end

%% adjust prestim and epoch parameters taking tube delay and trigger
% artefact window into account
prestim = (prestim + tube_delay) - trigger_artefact_window; % compute prestim duration
s_epoch = trigger_artefact_window; % compute start time of epoch (which includes baseline / prestim, but not the trigger artefact)
e_epoch = s_epoch + prestim + epoch_dur; % compute end time of epoch

% convert epoch start and end times to seconds
s_epoch_s = s_epoch/1000;
e_epoch_s = e_epoch/1000;
prestim_s = prestim/1000;

%% specify file directory - assumes data for every participant is in a
% separate subfolder within the specified file directory
fileDirectory = [fileDir '\' listener];
% get a list of BDF files
Files = dir(fullfile(fileDirectory, '*.bdf'));
nFiles = size(Files);

% create output directory within main file directory
OutputDir = [fileDir '\' 'EEGlab Output\ABR' ];
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

%% Prep for EEGLAB
% add path to eeglab
addpath('eeglab14_1_1b')

% start eeglab
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% specify active and reference channels & recode reference channel for re-referencing
[Act, Ref, reref] = BIOSEMI_channel(Active, Reference);

%% loop through all the files in the directory
for i=1:nFiles(1)
    fileName = Files(i).name;
    [pathstr, name, ext] = fileparts(fileName);
    
    % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
    EEG = pop_biosig((fullfile(fileDirectory,fileName)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
    
    % filter based on filtfilt (so effectively zero phase shift)
    EEG.data = butter_filtfilt(EEG.data, Lcut_off, Hcut_off, order);
    
    % epoch (sampling without replacement)
    totalsweeps = length(EEG.event)-2;
    epoch = epochEEG(EEG,totalsweeps,s_epoch_s,e_epoch_s,'without');
    
    % baseline correction
    epoch_corrected = baseline_correction(epoch,totalsweeps,prestim_s,EEG.srate);
    
    % artefact rejection: remove epochs that exceed +/- a given threshold
    [epoch_corrected, accepted, rejected] = rejectArtefacts(epoch_corrected, totalsweeps,artefact);
    
    % average across epochs
    avg = mean(epoch_corrected,1);
    
    % compute standard error of the mean across epochs for plotting
    SEM = std(epoch_corrected,1)/sqrt(accepted);
    
    % plot averaged response +/- standard error of the mean
    figure('color','white')
    s = (length(avg)/EEG.srate)*1000;
    t = (0:(s/(length(avg)-1)):s);
    % plot gray shaded area mean +/- standard error of the mean
    t2 = [t, fliplr(t)];
    inBetween = [avg+SEM, fliplr(avg-SEM)];
    fill(t2, inBetween, [0.8,0.8,0.8], 'LineStyle','none');
    hold on
    % plot averaged response
    p = plot(t,avg);
    ylim([-0.5, 0.5]);
    set(0, 'DefaulttextInterpreter', 'none')
    title(['', name, '']);
    xlabel('ms');
    ylabel('uV')
    set(p, 'Color', 'Black');
    % save figure
    saveas(gcf,['', OutputDir, '\', name,'_',Active, '_vs_',Reference, '_average', ''],'fig');
    
    % save averaged EEG mat files
    save(['', OutputDir, '\', name, '_',Active, '_vs_',Reference, '_average.mat', ''],'avg');
    
    % print out relevant information to csv file
    fTrackOut = fopen(OutFile, 'at');
    fprintf(fTrackOut, '\n%s,%s,%d,%d', ...
        OutputDir,name,accepted,rejected);
    fclose(fTrackOut);
    
    % clear all
    clear ALLCOM ALLEEG CURRENTSET CURRENTSTUDY EEG LASTCOM STUDY rm_index
end

fprintf('%s%s','Finished analysing ABR data for: ',listener)

clear all
close all
