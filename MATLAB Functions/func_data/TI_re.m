clc;
clear;
%% 读取IQ配置文件
installDir = matlabshared.supportpkg.getSupportPackageRoot;
tiradarCfgFileDir = fullfile(installDir,'toolbox','target', 'supportpackages', 'timmwaveradar', 'configfiles');
cd(tiradarCfgFileDir)
% tiradar.ConfigFile = "C:\Users\xiaoy\Desktop\毫米波雷达\课题\数据集\profile_2025_07_01T09_12_03_038.cfg";
% Create connection to TI Radar board and DCA1000EVM Capture card 
dca = dca1000("IWR6843ISK");
% Initialize variables
% Define a variable to set the sampling rate in Hz for the 
% phased.RangeDopplerScope object. The dca1000 object provides the 
% sampling rate in kHz;
% convert this rate to Hz.
fs = dca.ADCSampleRate*1e3;
% Define a variable to set the center frequency in Hz for the 
% phased.RangeDopplerScope object. The dca1000 object provides the 
% center frequency in GHz, convert this rate to Hz.
fc = dca.CenterFrequency*1e9;
% Define a variable to set the pulse repetition period in seconds for the 
% phased.RangeDopplerScope object. Because the dca1000 object provides the 
% chirp cycle time in us, convert this rate to seconds. The value is
% multiplied by 2 in this example because we are plotting the data only for first 
% transmit channel out of 2 channels
tpulse = 2*dca.ChirpCycleTime*1e-6;
% Pulse repetition interval
prf = 1/tpulse;
% Define a variable to set the FMCW sweep slope in Hz/s for the 
% phased.RangeResponse object. The dca1000 object provides the 
% sweep slope in MHz/us; convert this sweep slope to Hz/s.
sweepslope = dca.SweepSlope*1e12;
% Samples per chirp or RangeFFTLength
nr = dca.SamplesPerChirp;
% Number of active receivers
nrx = dca.NumReceivers;
% Number of active transmitters
ntx = dca.NumTransmitters;
% Number of chirps
nchirp = dca.NumChirps;
% Number pf ADCsample
nADCsample = dca.SamplesPerChirp;
% Create range doppler scope to compute and display the response map. 
rdscope = phased.RangeDopplerScope(IQDataInput=true,...    
    SweepSlope = sweepslope,SampleRate = fs,...    
    DopplerOutput="Speed",OperatingFrequency=fc,...    
    PRFSource="Property",PRF=prf,...    
    RangeMethod="FFT",RangeFFTLength=nr, ...    
    ReferenceRangeCentered = false);
% The first call of the dca1000 class object may take longer due to the 
% configuration of the radar and the DCA1000EVM. To exclude the configuration 
% time from the loop's duration, make the first call to the dca1000 object
% before entering the loop.
% iqData = [];
% numframe = 1200;
% channel = 0;
% TempData = zeros(nADCsample,nrx,nchirp/ntx,ntx);
% TempData2 = zeros(nADCsample,nchirp/ntx,nrx,ntx);
% Temp=zeros(nADCsample,nchirp/ntx,nrx*ntx);
% Temp_reshaped=zeros(numframe,nADCsample,nchirp/ntx,nrx*ntx);
% for i = 1 : numframe
%     temp = dca();%96x4x64->96x8x32
% 
%     for j = 1:ntx                                             
%         TempData(:,:,:,j)  = temp(:,:,j:ntx:end); %96x4x32x2
%         TempData2=permute(TempData,[1 3 2 4]);
% 
%     end
%     Temp=reshape(TempData2,96,32,[]);
%     Temp_reshaped(i,:,:,:)=Temp;
%     % iqData = [iqData,temp];%96x8x32->96x8x32x1200  
% end
% iqData=squeeze(Temp_reshaped(:,:,1,:));
% filename=fullfile('C:\Users\xiaoy\Desktop\呼吸检测\','iqData.mat');
% save(filename,'iqData');
iqData = dca();
% Specify the duration in seconds for which the loop should run
stopTime=10;
ts = tic();
% Execute the loop until the stopTime specified is reached

while (toc(ts)<stopTime)
% Capture the ADC data (IQ data) from TI Radar board and DCA1000EVM   
    iqData = dca();
% Get the data from first receiver antenna and first transmitter antenna  
% (Every alternate pulse is from one transmitter antenna for this   
% configuration)   
    iqData = squeeze(iqData(:,1,1:2:end));
% %  Plot the range doppler response corresponding to the input signal,   
% % iqData.    
    rdscope(iqData);
end
% Stop streaming the data and release the non tunable properties
dca.release;