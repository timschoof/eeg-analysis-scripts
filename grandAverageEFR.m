function grandAverageEFR(fileDirectory)

% set starting values
Fs = 16384;

% set counters to zero
counterQ0 = 0;
counterQ4 = 0;
counterQ8 = 0;

counterN0 = 0;
counterN4 = 0;
counterN8 = 0;

% get a list of files
Files = dir(fullfile(fileDirectory, '*.mat'));
nFiles = size(Files);

% loop through all the files in the directory
for i=1:nFiles(1)
    fileName = Files(i).name;
    [pathstr, name, ext] = fileparts(fileName);
    cond = strtrim(regexp(name,'quiet|HPfilt','match'));
    depth = strtrim(regexp(name,'0depth|4depth|8depth','match'));
    
    % open file
    load(fullfile(fileDirectory,fileName))
    
    % create empty arrays
    if i == 1
       quiet0 = zeros(1,length(avg));
       quiet4 = zeros(1,length(avg));
       quiet8 = zeros(1,length(avg)); 
       
       noise0 = zeros(1,length(avg)); 
       noise4 = zeros(1,length(avg)); 
       noise8 = zeros(1,length(avg)); 
    end
    
    % add up responses by condition (quiet or noise) and modulation depth
    if strcmp(cond,'quiet') % for click ABR wave I
        if strcmp(depth,'0depth')
            quiet0 = avg;
            counterQ0 = counterQ0 + 1;
        elseif strcmp(depth,'4depth')
            quiet4 = avg;
            counterQ4 = counterQ4 + 1;
        elseif strcmp(depth,'8depth')
            quiet8 = avg;
            counterQ8 = counterQ8 + 1;
        end
    elseif strcmp(cond,'HPfilt') % for click ABR wave I
        if strcmp(depth,'0depth')
            noise0 = avg;
            counterN0 = counterN0 + 1;
        elseif strcmp(depth,'4depth')
            noise4 = avg;
            counterN4 = counterN4 + 1;
        elseif strcmp(depth,'8depth')
            noise8 = avg;
            counterN8 = counterN8 + 1;
        end
    end
end

% average
avgQuiet0 = quiet0/counterQ0;
avgQuiet4 = quiet4/counterQ4;
avgQuiet8 = quiet8/counterQ8;

avgNoise0 = noise0/counterN0;
avgNoise4 = noise4/counterN4;
avgNoise8 = noise8/counterN8;

% plot EFRs
figure('color','white')
s = (length(avg)/Fs)*1000;
t = (0:(s/(length(avg)-1)):s);
% for quiet
p = plot(t,avgQuiet0); set(p,'color','black'); hold on
q = plot(t,avgQuiet4); set(q,'color','blue'); hold on
r = plot(t,avgQuiet8); set(r,'color','red');
xlabel('ms');
ylabel('uV')
legend('0 dB','-4 dB','-8 dB')
% save figure
saveas(gcf,['',fileDirectory, '\EFR_grandAverage_quiet',''],'fig');
%for noise
figure('color','white')
p = plot(t,avgNoise0); set(p,'color','black'); hold on
q = plot(t,avgNoise4); set(q,'color','blue'); hold on
r = plot(t,avgNoise8); set(r,'color','red');
xlabel('ms');
ylabel('uV')
legend('0 dB','-4 dB','-8 dB')
% save figure
saveas(gcf,['',fileDirectory, '\EFR_grandAverage_noise',''],'fig');

% plot FFT of grand average responses
% quiet
figure
[fftFFR, HzScale, dBfft] = myFFT(avgQuiet0,Fs,1,'EFR_grandAverage_quiet'); hold on
[fftFFR, HzScale, dBfft] = myFFT(avgQuiet4,Fs,1,'EFR_grandAverage_quiet'); hold on
[fftFFR, HzScale, dBfft] = myFFT(avgQuiet8,Fs,1,'EFR_grandAverage_quiet');
legend('0 dB','-4 dB','-8 dB')
% save figure
saveas(gcf,['',fileDirectory, '\EFR_grandAverage_FFT_quiet',''],'fig');
% noise
figure
[fftFFR, HzScale, dBfft] = myFFT(avgNoise0,Fs,1,'EFR_grandAverage_noise'); hold on
[fftFFR, HzScale, dBfft] = myFFT(avgNoise4,Fs,1,'EFR_grandAverage_noise'); hold on
[fftFFR, HzScale, dBfft] = myFFT(avgNoise8,Fs,1,'EFR_grandAverage_noise');
legend('0 dB','-4 dB','-8 dB')
% save figure
saveas(gcf,['',fileDirectory, '\EFR_grandAverage_FFT_noise',''],'fig');




                