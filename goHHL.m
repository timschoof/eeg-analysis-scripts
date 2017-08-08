function goHHL(listener)
% Horizontal montage: EXG3 – EXG4 for click ABR wave I
% Vertical montage: EXG1 – EXG3 for click ABR wave V
% Vertical montage: EXG1 – EXG2 for EFR

resultsDir = 'P:\HHL\Results\ABR pilot';

% horizontal configuration - for wave I
eeglab_ABR(resultsDir,listener,'EXG3','EXG4',100,3000,25,10,5)

% vertical configuration - for wave V
eeglab_ABR(resultsDir,listener,'EXG1','EXG3',100,3000,25,10,5)