RapidEFR_analysis('P:\HHL\Results\EFR pilot', 'Ax', 'EXG1', 'EXG2','phaselocked', 'without', 7500, 128)
RapidEFR_analysis('P:\HHL\Results\EFR pilot', 'Ax', 'EXG1', 'EXG2','phaselocked', 'without', 6000, 128)

ABR_analysis('P:\HHL\Results\ABR pilot', 'tim','EXG1', 'EXG3+4',62.5, 46, 70,1500, 25)

StandardEFR_analysis('P:\HHL\Results\EFR pilot', 'GM','EXG1', 'EXG3+4',1000*(10/152), 40, 70,1500, 25,176)


% %%
% 
% pd = POS.data;
% nd = NEG.data;
% 
% Lcut_off = 70;
% Hcut_off = 1500;
% order = 4;
% 
% %%

p = POS.data(POS.event(2).latency: POS.event(2).latency + (4500*(1/128)*POS.srate)); %67500
n = NEG.data(NEG.event(2).latency: NEG.event(2).latency + (4500*(1/128)*NEG.srate));

add = (p + n)/2;

myFFT(add,NEG.srate,1,'4500 nReps - 128 Hz - added polarities');

% 
% myFFT(POS.data,NEG.srate,1,'first 4500 nReps - 128 Hz - pos');
% myFFT(NEG.data,NEG.srate,1,'first 4500 nReps - 128 Hz - neg');