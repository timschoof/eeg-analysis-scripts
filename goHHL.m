function goHHL(listener)
% Horizontal montage: EXG3 – EXG4 for click ABR wave I
% Vertical montage: EXG1 – EXG3 for click ABR wave V
% Vertical montage: EXG1 – EXG2 (or EXG3+4) for EFR

% resultsDir = 'D:\HHL\ABR';
% 
% % horizontal configuration - for wave I
% % ABR_analysis(fileDir, listener,Active, Reference,epoch_dur, prestim, Lcut_off, Hcut_off, artefact)
% ABR_analysis(resultsDir, listener,'EXG3','EXG4',10,5)
% 
% % vertical configuration - for wave V
% ABR_analysis(resultsDir, listener,'EXG1','EXG3',10,5)

% EFR
resultsDir = 'D:\HHL\EFR';
% % signal
% % StandardEFR_analysis(fileDir, listener,Active, Reference,epoch_dur, prestim_dur, Lcut_off, Hcut_off, artefact, F0, F1, F2, F3, nzFloorBuffer, nzFloorWidth,rmTrig, window)
% StandardEFR_analysis(resultsDir, listener,'EXG1','EXG2',(1000*(10/176))+12, 40, 120, 2000, 25, 176,2*176,3*176,4*176,3,13,'T','signal') % 'EXG3+4'
%noise floor
StandardEFR_analysis(resultsDir, listener,'EXG1','EXG2',40, 0, 120, 2000, 25, 176,2*176,3*176,4*176,0,10,'T','noise') % 'EXG3+4'
