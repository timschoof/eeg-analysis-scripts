function RapidEFR_analysis(fileDir, listener, Active, Reference,trigTiming, replacement, totalSweeps, F0, F1, F2, F3, F4, Lcut_off, Hcut_off, draws, repeats, chunks, s_epoch, e_epoch, prestim)
% EFR analysis script
%
% The script only reads in two or three channels. It assumes that the EEG data file only has a
% trigger at the start of the recording.

% The script assumes that the data is organised in folders for each participant separately.
% It only analyses added (not subtracted) polarities (i.e. EFR). It computes
% response's rms and spectral magnitudes at six specified frequencies.

% The timing of the triggers can be either phaselocked to the stimulus (i.e. spaced with equal
%   time intervals) or randomly placed. When triggers are phaselocked, you will obtain an EFR.
%   When triggers are placed randomly, you will only get noise. This is used to compute the noise floor of the outcome measures.

% Especially when computing the noise floor you may want to obtain a
%   distribution of the outcome measures. You can repeat the calculation
%   multiple times.

% When epoching the data, you can sample epochs with and without
%   replacement. When sampling with replacement, it is likely that some
%   epochs of data are picked more than once and other epochs are never
%   picked. When sampling with replacement, you probably want to obtain a
%   distribution of the outcome measures.

% If you're interested in only analysing a subsection of the response,
%   or if you want to see how the response changes over time, you can analyse
%   the response in chunks.

%% Parameters
% fileDir = file directory with .bdf files
% listener = participant id
% Active - active electrode (EXG1, EXG2, or EXG3)
% Reference - reference electrode (EXG2, EXG3, or EXG4)
% trigTiming = the timing or location of the triggers: 'phaselocked' to the stimulus
%   F0 cycles (to compute EFR or signal's response) or 'random' (to compute
%   noise floor)
% replacement = sampling 'with' or 'without' replacement
% totalSweeps = number of sweeps in the response (e.g. 7500)
% F0, F1, F2, F3, F4 = frequencies for which spectral magnitude is to be
%   computed
% Lcut_off - lower bound bandpass filter
% Hcut_off - upper bound bandpass filter
% draws = number of draws, or trials, picked per FFT calculation
% repeats = number of times to compute FFT
% chunks = number of chunks needed to analyze (e.g. total is 7500 nReps, but
%   you want to analyze 1500 nReps at a time, starting with 1-1500, then
%   1501-3000 etc., chunks would be set to 5)
% s_epoch = start time of an epoch
% e_epoch = end time of an epoch (typically its duration)
% prestim = duration of prestimulus silence

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
tube_delay = 1; % time it takes for sound to travel along the tubing of the insert earphones (in ms), this is added to the prestim
trigger_artefact_window = 2; % period affected by trigger artefact (in ms), this is excluded from the baseline and epoch

% if certain arguments are not specified, set them to their default value
if nargin <20
    prestim = 0;
end
if nargin<18
    s_epoch = 0;
    e_epoch = 1000*(1/F0);
end
if nargin<17
    chunks = 1;
end
if nargin<16
    repeats = 1;
end
if nargin<15
    draws = totalSweeps;
end
if nargin<13
    Lcut_off = 70;
    Hcut_off = 2000;
end
if nargin<9
    F1 = 2*F0;
    F2 = 3*F0;
    F3 = 4*F0;
    F4 = 5*F0;
end

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
outputfile = ['', OutputDir,'\',listener '_EFR.csv', ''];
% write some headings and preliminary information to the output file
if ~exist(outputfile)
    fout = fopen(outputfile, 'at');
    fprintf(fout, 'file,listener,triggers,repeats,repetition,sweeps,chunk,Freq1,Freq2,Freq3,Freq4,Freq5,rms\n');
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
        
        trimmedFN = regexprep(fileName, 'pos_', ''); % filename without polarity indication for naming of result files
        trimmedFileName = regexprep(trimmedFN, '.bdf', ''); % remove file extension
        
        % find matching file with negative polarity
        NegFile = regexprep(fileName, 'pos', 'neg');
        
        if exist(fullfile(fileDirectory,NegFile))
            % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
            NEG = pop_biosig((fullfile(fileDirectory,NegFile)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
            
            % filter based on filtfilt (so effectively zero phase shift)
            POS.data = butter_filtfilt(POS.data, Lcut_off, Hcut_off, order);
            NEG.data = butter_filtfilt(NEG.data, Lcut_off, Hcut_off, order);
            
%             %% Check whether the F0 of the EEG signal is what it should be and resample the signal if necessary
%             [a, b, totalSweeps] =  whatF0(POS,fileName, OutputDir, F0, prestim, totalSweeps);
%             [NEG.data, NEG.event.latency, totalSweeps] =  whatF0(NEG,fileName, OutputDir, F0, prestim, totalSweeps);
            
            %% Plot FFT of the whole response, before epoching, artefact rejection, and averaging
            % select FFR
            posWhole = POS.data(POS.event(2).latency: POS.event(2).latency + (totalSweeps*(1/F0)*POS.srate));
            negWhole = NEG.data(NEG.event(2).latency: NEG.event(2).latency + (totalSweeps*(1/F0)*NEG.srate));
            % add polarities
            addWhole = (posWhole + negWhole)/2;
            % FFT
            myFFT(addWhole,NEG.srate,1,['', trimmedFileName,' ', num2str(totalSweeps), ' nReps - ', num2str(F0),' Hz - added polarities']);
            % save figure
            saveas(gcf,['', OutputDir, '\', trimmedFileName,'_wholeResponse_FFT', ''],'fig');
            
            %% If desired, analyze chunks of the EEG signal one by one (shifting by a
            % certain number of sweeps). If chunks == 1, the whole EEG
            % signal will be analysed in one go
            for m = 1:chunks
                % determine the start and end point of the triggers (this
                % is particularly relevant when analyzing chunks of the EEG
                % signal one by one because the start and end points will
                % change)
                endSweep = m*(totalSweeps/chunks); % determine end point for triggers
                startSweep = endSweep-(totalSweeps/chunks)+1; % determine start point for triggers
                %% loop through number of repeats (to get a distribution of
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
                        EEG.event = create_triggers(EEG, draws, trigTiming, startSweep, endSweep, s_epoch_s,e_epoch_s, prestim_s);
                        
                        %% epoch the data - sampling with or without replacement
                        epoch = epochEEG(EEG,draws,s_epoch_s,e_epoch_s,replacement);
                        
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
                    [fftFFR, HzScale] = myFFT(add,NEG.srate,1,trimmedFileName);
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
                    fout = fopen(outputfile, 'at');
                    fprintf(fout, '%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n', ...
                        trimmedFileName,listener,char(trigTiming),repeats,l,draws,m,Freq1,Freq2,Freq3,Freq4,Freq5,sigrms);
                    fclose(fout);
                    
                    % remove POS, NEG eeg datasets
                    clear POS NEG
                end
            end
        end
    end
end

fprintf('%s%s','Finished analysing EFR data for: ',listener)

close all
clear all
