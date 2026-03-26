function [pitchSpectrogram,azimuSpectrogram,Rxv] = IWR6843ISK_DOA(rangeProfile,doaFlag,useChirpNum,searchAngleRange,c)
% Description: Perform DOA estimation for azimuth and elevation directions on a frame of data from the IWR1642ODS radar, generating an angle spectrum.

% Input:   
% rangeProfile: Range profile of a single frame after clutter removal
% doaFlag: DOA flag: doaFlag=0 FFT; doaFlag=1 CBF; doaFlag=2 MVDR
% useChirpNum: Number of chirps used for DOA estimation
% searchAngleRange: Angle search range, i.e., the search range of the spectrum when using CBF or MVDR algorithm, in degrees

% Output:
% pitchSpectrogram: Elevation angle spectrum
% azimuSpectrogram: Azimuth angle spectrum

% FFT_DOA_MODE   = 0;
CBF_DOA_MODE   = 1;
MVDR_DOA_MODE  = 2;

% Calculate angle spectrum using CBF and MVDR
% Note: Only one-dimensional CBF method is used to calculate azimuth and elevation angle spectra separately
rangNum = size(rangeProfile,2);
lambda = 5e-3; % Wavelength
d = lambda / 2; % Element spacing
if (doaFlag == CBF_DOA_MODE) || (doaFlag == MVDR_DOA_MODE)
    SEARCH_ANGLE_RANGE = searchAngleRange/180*pi; % Search angle range (in radians)
    SEARCH_ANGLE_SPACE = 1/180*pi; % Search angle interval (in radians)
    fai = 2 * pi * sin(-SEARCH_ANGLE_RANGE:SEARCH_ANGLE_SPACE:SEARCH_ANGLE_RANGE) * d / lambda; % fai = 2πd sin(θ)/λ 1x121 double
    azimuSpectrogram = zeros(length(fai),rangNum);
    pitchSpectrogram = zeros(length(fai),rangNum);
    for r = 1:rangNum
        %-------------------------------------Azimuth
%         xt = [rangeProfile(1:useChirpNum,r,2),rangeProfile(1:useChirpNum,r,3),rangeProfile(1:useChirpNum,r,6),rangeProfile(1:useChirpNum,r,7)].';%,rangeProfile(1:useChirpNum,r,2),rangeProfile(1:useChirpNum,r,3),rangeProfile(1:useChirpNum,r,6),rangeProfile(1:useChirpNum,r,7)
         xt = squeeze(rangeProfile(1:useChirpNum-c,r,:))';
         Rx = xt * xt'; % Calculate covariance matrix 
        for an = 1:length(fai)
            aTheta = [1,exp(-j*1*fai(an)),exp(-j*2*fai(an)),exp(-j*3*fai(an)),exp(-j*4*fai(an)),exp(-j*5*fai(an)),exp(-j*6*fai(an)),exp(-j*7*fai(an))];%
            if (doaFlag == CBF_DOA_MODE) % CBF
                azimuSpectrogram(an,r) = abs(aTheta * Rx * aTheta'); 
            else % MVDR
                Rxv = pinv(Rx);  
                azimuSpectrogram(an,r) = 1 / abs(aTheta * Rxv * aTheta');
            end
        end
    end
end
AzimuSpectrogram = azimuSpectrogram / max(azimuSpectrogram);
%  azimuSpectrogram=10*log10(azimuSpectrogram);
%  figure;
%  plot(20*fai,10*log10(AzimuSpectrogram)); xlabel('Angle'); ylabel('dB'); title('MVDR Angle Resolution');
end