function RapidEFR_analysis(fileDir, listener, outFileName, condition, draws, repeats, totalSweeps, chunks,s_epoch, e_epoch, prestim, F0, F1, F2, F3, F4,replacement)
% EFR analysis script
% Only reads in two channels.
% Assumes data is organised in folders for each participant separately.
% Only analyses added (not subtracted) polarities (i.e. EFR).

% Sampling with and without replacement
% Randomized or phaselocked trigger placement
% Chunks
% Repeats

%% Parameters
% condition = 'random' or 'phaselocked'
% draws = number of draws, or trials picked per FFT calculation (e.g. 400; so half is pos, half is neg)
% repeats = number of times to compute FFT; 100 for phase-locked, 1000 for random
% totalSweeps = number of sweeps in the response (e.g. 7500)
% chunk = number of chunks needed to analyze (e.g. total is 7500 nReps, but
% you want to analyze 1500 nReps at a time, staring with 1-1500, then
% 1501-3000 etc.)

%% Version
% Version 1 - September 2017
%   This script is based on various previous (messy!) versions - this is an
%   attempt to clean things up.
%
% Dependencies:
%  * eeglab
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
% ----------------------------------------

%% some starting values
order = 2; % butterworth filter order
artefact = 25; % epochs containing values exceeding +/- this value (in uV) are
% considered artefacts and removed from the set of epochs
% tube_delay = 1; % time it takes for sound to travel along the tubing of the insert earphones (in ms), this is added to the prestim
% trigger_artefact_window = 2; % period affected by trigger artefact (in ms), this is excluded from the baseline and epoch

% %% adjust prestim and epoch parameters taking tube delay and trigger
% % artefact window into account
% prestim = (prestim + tube_delay) - trigger_artefact_window; % compute prestim duration
% s_epoch = trigger_artefact_window; % compute start time of epoch (which includes baseline / prestim, but not the trigger artefact)
% e_epoch = s_epoch + prestim + epoch_dur; % compute end time of epoch

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

%% create output files
% create output directory within main file directory
OutputDir = [fileDir '\' 'EEGlab Output\EFR' ];
mkdir(OutputDir)

% Output file for number of rejected and accepted sweeps
OutSweepFile = [OutputDir '\' listener  '_rejected_sweeps' '.csv'];
% write some headings and preliminary information to the output file
WriteHeader = exist(OutSweepFile);
fTrackOut = fopen(OutSweepFile, 'at');
if ~WriteHeader
    fprintf(fTrackOut, 'listener,response,accepted,rejected');
    fclose(fTrackOut);
end

% construct the output data file name
outfile = ['', OutputDir,'\',outFileName,'.csv', ''];
% write some headings and preliminary information to the output file
if ~exist(outfile)
    fout = fopen(outfile, 'at');
    fprintf(fout, 'file,listener,condition,repeats,repetition,sweeps,chunk,Freq1,Freq2,Freq3,Freq4,Freq5,rms\n');
    fclose(fout);
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
    polarity = strtrim(regexp(name,'pos|neg','match'));
    listener = name(1:3);
    
    if strcmp(polarity,'pos')
        % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
        POS = pop_biosig((fullfile(fileDirectory,fileName)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
        
        trimmedFileName = regexprep(fileName, 'pos_', ''); % filename without polarity indication for naming of result files
        
        % find matching file with negative polarity
        NegFile = regexprep(fileName, 'pos', 'neg');
        
        if exist(fullfile(fileDirectory,NegFile))
            % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
            NEG = pop_biosig((fullfile(fileDirectory,NegFile)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
            
            % filter based on filtfilt (so effectively zero phase shift)
            POS.data = butter_filtfilt(POS.data, Lcut_off, Hcut_off, order);
            NEG.data = butter_filtfilt(NEG.data, Lcut_off, Hcut_off, order);
                        
            % If desired, analyze chunks of the EEG signal one by one (shifting by a
            % certain number of sweeps). If chunks == 1, the whole EEG
            % signal will be analysed in one go
            for m = 1:chunks 
                % determine the start and end point of the triggers (this
                % is particularly relevant when analyzing chunks of the EEG
                % signal one by one because the start and end points will
                % change)
                endSweep = m*(totalSweeps/chunks); % determine end point for triggers
                startSweep = endSweep-(totalSweeps/chunks)+1; % determine start point for triggers
                % loop through number of repeats (to get a distribution of
                % the response measures)
                for l = 1:repeats
                    % loop through positive and negative polarities
                    for jj = 1:2 
                        if jj == 1
                            EEG = POS;
                        elseif jj == 2
                            EEG = NEG;
                        end
                        
                        %% create triggers - either phaselocked to the response (signal) or
                        % placed randomly (noise)
                        EEG.event = create_triggers(EEG, nTrigs, trigTiming, startSweep, endSweep, s_epoch_s,e_epoch_s, prestim);
                        
                        %% epoch the data - sampling with or without replacement
                        epoch = epochEEG(EEG,draws,replacement);                        
                        
                        %% artefact rejection: remove epochs that exceed +/- a given threshold
                        [epoch, accepted, rejected] = rejectArtefacts(epoch, draws,artefact);
                        
                        % print out number of accepted and rejected sweeps to csv file
                        % first, make sure correct file name is used
                        if jj == 1
                            fName = fileName; % file name positive polarity response
                        elseif jj == 2
                            fName = NegFile; % file name negative polarity response
                        end
                        % save
                        fTrackOut = fopen(OutSweepFile, 'at');
                        fprintf(fTrackOut, '\n%s,%s,%d,%d', ...
                            listener,fName,accepted,rejected);
                        fclose(fTrackOut);
                        
                        %% average across draws
                        avg = mean(epoch,1);
                        
                        if jj == 1
                            posAVG = avg;
                        elseif jj == 2
                            negAVG = avg;
                        end
                    end
                    
                    %% add and subtract polarities
                    add = (posAVG + negAVG)/2;
                    
                    %% Compute rms and FFT & save away results
                    % rms
                    sigrms = rms(add');
                    
                    % compute and plot FFT
                    [fftFFR, HzScale] = myFFT(add,NEG.srate,trimmedFileName);
                    % save figure
                    saveas(gcf,['', OutputDir, '\', trimmedFileName,'_FFT', ''],'fig');
                    
                    % Compute spectral mangitudes
                    % Freq1
                    FreqInd = find(HzScale==F0,1);
                    Freq1 = fftFFR(FreqInd);
                    % Freq2
                    FreqInd = find(HzScale==F1,1);
                    Freq2 = fftFFR(FreqInd);
                    % Freq3
                    FreqInd = find(HzScale==F2,1);
                    Freq3 = fftFFR(FreqInd);
                    % Freq4
                    FreqInd = find(HzScale==F3,1);
                    Freq4 = fftFFR(FreqInd);
                    % Freq5
                    FreqInd = find(HzScale==F4,1);
                    Freq5 = fftFFR(FreqInd);
                    
                    % print out relevant information
                    fout = fopen(outfile, 'at');
                    fprintf(fout, '%s,%s,,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n', ...
                        trimmedFileName,listener,char(condition),repeats,l,draws,m,Freq1,Freq2,Freq3,Freq4,Freq5,sigrms);
                    fclose(fout);
                    
                    % remove POS, NEG eeg datasets
                    clear POS NEG
                end
            end
        end
    end
end

close all
clear all

fprintf('%s%s','Finished analysing EFR data for: ',listener)
