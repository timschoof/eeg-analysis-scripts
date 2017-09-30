function RapidEFR_analysis(fileDir, listener, trigTiming, replacement, totalSweeps, F0, F1, F2, F3, F4, draws, repeats, chunks, s_epoch, e_epoch, prestim)
% EFR analysis script
%
% The script only reads in two channels. It assumes that the EEG data file only has a
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
% trigTiming = the timing or location of the triggers: 'phaselocked' to the stimulus 
%   F0 cycles (to compute EFR or signal's response) or 'random' (to compute
%   noise floor)
% replacement = sampling 'with' or 'without' replacement
% draws = number of draws, or trials, picked per FFT calculation
% repeats = number of times to compute FFT
% totalSweeps = number of sweeps in the response (e.g. 7500)
% chunks = number of chunks needed to analyze (e.g. total is 7500 nReps, but
%   you want to analyze 1500 nReps at a time, starting with 1-1500, then
%   1501-3000 etc., chunks would be set to 5)
% s_epoch = start time of an epoch
% e_epoch = end time of an epoch (typically its duration)
% prestim = duration of prestimulus silence
% F0, F1, F2, F3, F4 = frequencies for which spectral magnitude is to be
%   computed 

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

% if certain arguments are not specified, set them to their default value
if nargin <16
    prestim = 0;
end
if nargin<14
    s_epoch = 1; % I think this should be 1, not 0
    e_epoch = 1000*(1/F0);
end
if nargin<13
    chunks = 1;
end
if nargin<12
    repeats = 1;
end
if nargin<11
    draws = totalSweeps;
end
if nargin<7
    F1 = 2*F0;
    F2 = 3*F0;
    F3 = 4*F0;
    F4 = 5*F0;
end

% adjust prestim taking tube delay into account
prestim = (prestim + tube_delay) - trigger_artefact_window; % compute prestim duration

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
outfile = ['', OutputDir,'\',listener '_EFR.csv', ''];
% write some headings and preliminary information to the output file
if ~exist(outfile)
    fout = fopen(outfile, 'at');
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
        
        trimmedFileName = regexprep(fileName, 'pos_', ''); % filename without polarity indication for naming of result files
        
        % find matching file with negative polarity
        NegFile = regexprep(fileName, 'pos', 'neg');
        
        if exist(fullfile(fileDirectory,NegFile))
            % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
            NEG = pop_biosig((fullfile(fileDirectory,NegFile)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
            
            % filter based on filtfilt (so effectively zero phase shift)
            POS.data = butter_filtfilt(POS.data, Lcut_off, Hcut_off, order);
            NEG.data = butter_filtfilt(NEG.data, Lcut_off, Hcut_off, order);
                    
            % save data plus initial trigger as .mat file
            for j = 1:2 % loop through polarities
                if j == 1
                    EEGwave = POS;
                    fName = fileName;
                else
                    EEGwave = NEG;
                    fName = NegFile;
                end
                for k = 2:length(EEGwave.event)
                    triggerLocation = EEGwave.event(:,k).latency;
                    trigg = zeros(1,length(EEGwave.data));
                    trigg(triggerLocation) = 1;
                end
                
                ffr=[EEGwave.data;trigg];
                ffr=ffr';
                save(['',OutputDir,'\',fName,'.mat',''],'ffr')
            end
            
            %% resample the signal if necessary
            whatF0
            
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
                        trimmedFileName,listener,char(trigTiming),repeats,l,draws,m,Freq1,Freq2,Freq3,Freq4,Freq5,sigrms);
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
