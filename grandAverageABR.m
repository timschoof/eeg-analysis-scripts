function grandAverageABR(fileDirectory, group, excludeFile)
% Horizontal montage: EXG3 – EXG4 for click ABR wave I
% Vertical montage: EXG1 – EXG3 for click ABR wave V

% set starting values
Fs = 16384;

% set counters to zero
counterI95 = 0;
counterI105 = 0;
counterI115 = 0;

counterV95 = 0;
counterV105 = 0;
counterV115 = 0;

% get a list of files
Files = dir(fullfile(fileDirectory, [group,'*.mat']));
nFiles = size(Files);

% exclude files that are in the noise floor
if nargin>2
    excl = robustcsvread(fullfile(fileDirectory,excludeFile));
    cntr = 0;
    
    for i=1:nFiles(1)
        fileName = Files(i).name;
        newStr = erase(fileName,'.mat');
        for j=1:length(excl)
            if strcmp(newStr, char(excl{j}))
                cntr = cntr + 1;
                excludeRows(cntr) = i;
            end
        end
    end
    Files(flip(excludeRows)) = [];
    nFiles = size(Files);
end

% loop through all the files in the directory
for i=1:nFiles(1)
    fileName = Files(i).name;
    [pathstr, name, ext] = fileparts(fileName);
    cond = strtrim(regexp(name,'EXG3_vs_EXG4|EXG1_vs_EXG3','match'));
    level = strtrim(regexp(name,'95dB|105dB|115dB','match'));
    
    % open file
    load(fullfile(fileDirectory,fileName))
    
    % create empty arrays
    if i == 1
       waveI95 = zeros(1,length(avg));
       waveI105 = zeros(1,length(avg));
       waveI115 = zeros(1,length(avg)); 
       
       waveV95 = zeros(1,length(avg)); 
       waveV105 = zeros(1,length(avg)); 
       waveV115 = zeros(1,length(avg)); 
    end
    
    % add up responses by electrode configuration and level
    if strcmp(cond,'EXG3_vs_EXG4') % for click ABR wave I
        if strcmp(level,'95dB')
            waveI95 = avg;
            counterI95 = counterI95 + 1;
        elseif strcmp(level,'105dB')
            waveI105 = avg;
            counterI105 = counterI105 + 1;
        elseif strcmp(level,'115dB')
            waveI115 = avg;
            counterI115 = counterI115 + 1;
        end
    elseif strcmp(cond,'EXG1_vs_EXG3') % for click ABR wave I
        if strcmp(level,'95dB')
            waveV95 = avg;
            counterV95 = counterV95 + 1;
        elseif strcmp(level,'105dB')
            waveV105 = avg;
            counterV105 = counterV105 + 1;
        elseif strcmp(level,'115dB')
            waveV115 = avg;
            counterV115 = counterV115 + 1;
        end
    end
end

% average
avgWaveI95 = waveI95/counterI95;
avgWaveI105 = waveI105/counterI105;
avgWaveI115 = waveI115/counterI115;

avgWaveV95 = waveV95/counterV95;
avgWaveV105 = waveV105/counterV105;
avgWaveV115 = waveV115/counterV115;

% plot ABRs
figure('color','white')
s = (length(avg)/Fs)*1000;
t = (0:(s/(length(avg)-1)):s);
% for wave I
p = plot(t,avgWaveI95); set(p,'LineWidth',2); hold on
q = plot(t,avgWaveI105); set(q,'LineWidth',2); hold on
r = plot(t,avgWaveI115); set(r,'LineWidth',2);
xlabel('ms');
ylabel('uV')
legend('95 dB peSPL','105 dB peSPL','115 dB peSPL')
% save figure
saveas(gcf,['',fileDirectory, '\ABR_grandAverage_horizontal_',group,''],'fig');
saveas(gcf,['',fileDirectory, '\ABR_grandAverage_horizontal_',group,''],'tiff');
%for wave V
figure('color','white')
p = plot(t,avgWaveV95); set(p,'LineWidth',2); hold on
q = plot(t,avgWaveV105); set(q,'LineWidth',2); hold on
r = plot(t,avgWaveV115); set(r,'LineWidth',2);
xlabel('ms');
ylabel('uV')
legend('95 dB peSPL','105 dB peSPL','115 dB peSPL')
% save figure
saveas(gcf,['',fileDirectory, '\ABR_grandAverage_vertical_',group,''],'fig');
saveas(gcf,['',fileDirectory, '\ABR_grandAverage_vertical_',group,''],'tiff');
                
close all



                