function goHHL(listener)
% Horizontal montage: EXG3 – EXG4 for click ABR wave I
% Vertical montage: EXG1 – EXG3 for click ABR wave V
% Vertical montage: EXG1 – EXG2 for EFR

resultsDir = 'P:\HHL\Results\ABR pilot';

% horizontal configuration - for wave I
% ABR_analysis(fileDir, listener,Active, Reference,epoch_dur, prestim, Lcut_off, Hcut_off, artefact)
ABR_analysis(resultsDir, listener,'EXG3','EXG4',10,5)

% vertical configuration - for wave V
ABR_analysis(resultsDir, listener,'EXG1','EXG3',10,5)

% EFR
% RapidEFR_analysis(fileDir, listener, trigTiming, replacement, totalSweeps, F0, F1, F2, F3, F4, draws, repeats, chunks, s_epoch, e_epoch, prestim)