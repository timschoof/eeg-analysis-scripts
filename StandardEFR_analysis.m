function StandardEFR_analysis(fileDir, listener, Active, Reference, epoch_dur, prestim_dur, Lcut_off, Hcut_off, artefact, F0, F1, F2, F3, nzFloorBuffer, nzFloorWidth, rmTrig, window)
% EFR analysis script -- for EFRs collected using the standard technique
% (i.e. when the stimulus is presented with an ISI and triggers, and not
% continuously).
%
% Only reads in two or three channels.
% The script assumes that the data is organised in folders for each participant separately.
% It only analyses added (not subtracted) polarities (i.e. EFR). It computes
% response's rms and spectral magnitudes at six specified frequencies.
%
% The script assumes that there is a folder called 'stimuli' in the file
% directory with all the stimuli in .wav format (single repetition of
% stimulus, no triggers, no prestim). Note that the stimulus files need to
% match the name of the condition as specified in the BDF files so they can
% be matched up later.
% This will be used to compute stimulus-to-response correlations and
% determine the exact time-window of the EFR.

%% parameters
% fileDirectory - folder with files to be processed
% Active - active electrode (EXG1, EXG2, or EXG3)
% Reference - reference electrode (EXG2, EXG3, or EXG4)
% considered artefacts and removed from the set of epochs
% epoch_dur - duration (in ms) of epoch (excluding the prestim)
% prestim_start - start time of the prestim relative to the trigger
%   (default = 0). If negative, the prestim starts before the trigger.
% prestim_dur - duration of the baseline (i.e. end time (in ms) of pre-stim)
% Lcut_off - lower bound bandpass filter
% Hcut_off - upper bound bandpass filter
% artefact - epochs containing values exceeding +/- this value (in uV) are
% F0, F1, F2, F3, F4 = frequencies for which spectral magnitude is to be
%   computed
% rmTrig - T (true) or F (false): is there are trigger artefact that should
%   be removed? If the. If F, the trigger artifact is assumed to be at the
%   start of each epoch and the first 2 ms will be removed.
% window - signal or noise: are you analysing the FFR or the noise floor?

%% Version
% Version 1.0 - October 2017
%       Based on ABR_analysis and RapidEFR_analysis scripts.
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
tube_delay = 1; % time it takes for sound to travel along the tubing of the insert earphones (in ms), this is added to the prestim

% if certain arguments are not specified, set them to their default value
if nargin<13
    window = 'signal';
end
if nargin<12
    rmTrig = 'F';
end
if nargin<11
    F1 = 2*F0;
    F2 = 3*F0;
    F3 = 4*F0;
    F4 = 5*F0;
end
if nargin<10
    F0 = 128;
end
if nargin<9
    artefact = 25;
end
if nargin<8
    Hcut_off = 2000;
end
if nargin<7
    Lcut_off = 70;
end

% cut off trigger artifact if it's not being removed later on
if strcmp(rmTrig,'T')
    % period affected by trigger artefact (in ms), this is excluded from the baseline and epoch
    trigger_artefact_window = 2;
else
    trigger_artefact_window = 0;
end

%% adjust prestim and epoch parameters taking tube delay and trigger
% artefact window into account
prestim_dur = (prestim_dur + tube_delay) - trigger_artefact_window; % compute prestim duration
s_epoch = trigger_artefact_window; % compute start time of epoch (which includes baseline / prestim, but not the trigger artefact)
e_epoch = s_epoch + prestim_dur + epoch_dur; % compute end time of epoch

% convert epoch start and end times to seconds
s_epoch_s = s_epoch/1000;
e_epoch_s = e_epoch/1000;
prestim_s = prestim_dur/1000;

%% specify file directory - assumes data for every participant is in a
% separate subfolder within the specified file directory
fileDirectory = [fileDir '\' listener];
% get a list of BDF files
Files = dir(fullfile(fileDirectory, '*.bdf'));
nFiles = size(Files);

% create output directory within main file directory
OutputDir = [fileDir '\' 'EEGlab Output\EFR' ];
mkdir(OutputDir)

% create output file for number of rejected and accepted sweeps
OutSweepFile = [OutputDir '\' listener  '_rejected_sweeps' '.csv'];
% write some headings and preliminary information to the output file
WriteHeader = exist(OutSweepFile);
fTrackOut = fopen(OutSweepFile, 'at');
if ~WriteHeader
    fprintf(fTrackOut, 'listener,response,window,accepted,rejected');
    fclose(fTrackOut);
end

% construct the output data file name
outputfile = ['', OutputDir,'\',listener '_EFR.csv', ''];
% write some headings and preliminary information to the output file
if ~exist(outputfile)
    fout = fopen(outputfile, 'at');
    fprintf(fout, 'file,listener,window,Freq1,Freq2,Freq3,Freq4,Freq1NZ,Freq2NZ,Freq3NZ,Freq4NZ,rms,SRlag,SRcorr\n');
    fclose(fout);
end

%% specify directory with stimulus .wav files
% separate subfolder within the specified file directory
stimDirectory = [fileDir '\stimuli'];
% get a list of wav files
sFiles = dir(fullfile(stimDirectory, '*.wav'));
nsFiles = size(sFiles);

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
    polarity = strtrim(regexp(name,'pos|neg|alt','match'));
    listener = name(1:3);
    
    if strcmp(polarity,'pos') || strcmp(polarity,'alt')
        % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
        POS = pop_biosig((fullfile(fileDirectory,fileName)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
        
        if strcmp(polarity,'pos')
            trimmedFN = regexprep(fileName, 'pos', ''); % filename without polarity indication for naming of result files
            trimmedFileName = regexprep(trimmedFN, '.bdf', ''); % remove file extension
            
            % find matching file with negative polarity
            NegFile = regexprep(fileName, 'pos', 'neg');
            
            if exist(fullfile(fileDirectory,NegFile))
                % load bdf file, extract only active and reference channel, reference data, and save as EEG data set
                NEG = pop_biosig((fullfile(fileDirectory,NegFile)), 'channels', [Act Ref],'ref',reref,'blockepoch','off','refoptions',{'keepref','off'});
            end
        end
        
        if strcmp(polarity,'alt')
            nJJ = 1;
        else
            nJJ = 2;
        end
        for jj = 1:nJJ
            if jj == 1
                EEG = POS;
            elseif jj == 2
                EEG = NEG;
            end
            
            % filter based on filtfilt (so effectively zero phase shift)
            EEG.data = butter_filtfilt(EEG.data, Lcut_off, Hcut_off, order);
            
            % epoch (sampling without replacement)
            totalsweeps = length(EEG.event)-2;
            epoch = epochEEG(EEG,totalsweeps,s_epoch_s,e_epoch_s,'without');
            
            % baseline correction
            if strcmp(window,'signal') % don't do this if you're analysing the noise floor
                epoch_corrected = baseline_correction(epoch,totalsweeps,prestim_s,EEG.srate);
            else
                epoch_corrected = epoch;
            end
            
            % artefact rejection: remove epochs that exceed +/- a given threshold
            [epoch_corrected, accepted, rejected] = rejectArtefacts(epoch_corrected, totalsweeps,artefact);
            
            % print out number of accepted and rejected sweeps to csv file
            % first, make sure correct file name is used
            if jj == 1
                fName = fileName; % file name positive polarity response
            elseif jj == 2
                fName = NegFile; % file name negative polarity response
            end
            % save
            fTrackOut = fopen(OutSweepFile, 'at');
            fprintf(fTrackOut, '\n%s,%s,%s,%d,%d', ...
                listener,fName,window,accepted,rejected);
            fclose(fTrackOut);
            
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
            set(0, 'DefaulttextInterpreter', 'none')
            title(['', name, '']);
            xlabel('ms');
            ylabel('uV')
            set(p, 'Color', 'Black');
            % save figure
            saveas(gcf,['', OutputDir, '\', name,'_',Active, '_vs_',Reference, '_average_',window, ''],'fig');
            
            % save averaged EEG mat files
            save(['', OutputDir, '\', name, '_',Active, '_vs_',Reference, '_average_',window,'.mat', ''],'avg');
            
            if jj == 1
                posAVG = avg;
            elseif jj == 2
                negAVG = avg;
            end
        end
        
        %% add and subtract polarities
        if strcmp(polarity,'alt')
            add = posAVG;
        else
            add = (posAVG + negAVG)/2;
        end
        
        %% Compute stimulus-to-response correlation to determine onset of FFR
        % loop through all stimulus files
        if strcmp(window, 'signal')
            for k=1:nsFiles(1)
                % determin name of stimulus file
                sfileName = sFiles(k).name;
                [pathstr, sName, ext] = fileparts(sfileName);
                % see if stimulus filename matches that of response
                condition = strtrim(regexp(name,sName,'match'));
                % load correct stimFile
                if ~isempty(condition)
                    [stimFile, StimFs] = audioread(fullfile(stimDirectory,sfileName));
                end
            end
            % resample stimFile if necessary
            if EEG.srate ~= StimFs
                [p,q] = rat(EEG.srate/StimFs);
                stimulus = resample(stimFile,p,q);
            end
            
            % stimulus to response correlation
            [LAG_ms, LAG_samp, SRcorr] = stimresp_corr(add', stimulus, epoch_dur, 5, 12, 'POSITIVE');
            
            % extract the EFR portion of the response
            EFR = add(LAG_samp:LAG_samp+length(stimulus)-1);
        else
            EFR = add;
        end
        %% Compute rms and FFT & save away results
        % rms
        sigrms = rms(EFR');
        
        % compute and plot FFT
        figure
        [fftFFR, HzScale, dBfft] = myFFT(EFR,EEG.srate,1,trimmedFileName);
        % save figure
        saveas(gcf,['', OutputDir, '\', trimmedFileName,'_',window,'_FFT', ''],'fig');
        
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
        
        % Noise floor around Freq1
        FreqInd_lo_bottom = find(HzScale==F0-nzFloorBuffer-nzFloorWidth,1);
        FreqInd_hi_bottom = find(HzScale==F0-nzFloorBuffer,1);
        FreqInd_lo_top = find(HzScale==F0+nzFloorBuffer,1);
        FreqInd_hi_top = find(HzScale==F0+nzFloorBuffer+nzFloorWidth,1);
        Freq1_nz = mean([fftFFR(FreqInd_lo_bottom:FreqInd_hi_bottom) fftFFR(FreqInd_lo_top:FreqInd_hi_top)]);
        
        % Noise floor around Freq2
        FreqInd_lo_bottom = find(HzScale==F1-nzFloorBuffer-nzFloorWidth,1);
        FreqInd_hi_bottom = find(HzScale==F1-nzFloorBuffer,1);
        FreqInd_lo_top = find(HzScale==F1+nzFloorBuffer,1);
        FreqInd_hi_top = find(HzScale==F1+nzFloorBuffer+nzFloorWidth,1);
        Freq2_nz = mean([fftFFR(FreqInd_lo_bottom:FreqInd_hi_bottom) fftFFR(FreqInd_lo_top:FreqInd_hi_top)]);
        
        % Noise floor around Freq3
        FreqInd_lo_bottom = find(HzScale==F2-nzFloorBuffer-nzFloorWidth,1);
        FreqInd_hi_bottom = find(HzScale==F2-nzFloorBuffer,1);
        FreqInd_lo_top = find(HzScale==F2+nzFloorBuffer,1);
        FreqInd_hi_top = find(HzScale==F2+nzFloorBuffer+nzFloorWidth,1);
        Freq3_nz = mean([fftFFR(FreqInd_lo_bottom:FreqInd_hi_bottom) fftFFR(FreqInd_lo_top:FreqInd_hi_top)]);
        
        % Noise floor around Freq4
        FreqInd_lo_bottom = find(HzScale==F3-nzFloorBuffer-nzFloorWidth,1);
        FreqInd_hi_bottom = find(HzScale==F3-nzFloorBuffer,1);
        FreqInd_lo_top = find(HzScale==F3+nzFloorBuffer,1);
        FreqInd_hi_top = find(HzScale==F3+nzFloorBuffer+nzFloorWidth,1);
        Freq4_nz = mean([fftFFR(FreqInd_lo_bottom:FreqInd_hi_bottom) fftFFR(FreqInd_lo_top:FreqInd_hi_top)]);
        
        % print out relevant information
        fout = fopen(outputfile, 'at');
        fprintf(fout, '%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n', ...
            trimmedFileName,listener,window,Freq1,Freq2,Freq3,Freq4,Freq1_nz,Freq2_nz,Freq3_nz,Freq4_nz,sigrms, LAG_ms, SRcorr);
        fclose(fout);
        
        % clear all
        clear ALLCOM ALLEEG POS NEG CURRENTSET CURRENTSTUDY EEG LASTCOM STUDY rm_index
    end
end

fprintf('%s%s','Finished analysing EFR data for: ',listener)

clear all
close all
