function dopplerFFTData = fft2dwindow(mergedData, windowType, N, dopplerDim)
% FFT2DWINDOW 通用型2D（Doppler）FFT加窗函数（适配雷达多维数据）
% 用法:
%   dopplerFFTData = fft2dwindow(mergedData, windowType, N, dopplerDim)
% 输入参数:
%   mergedData   - 任意维度的雷达复数数据（如4维[Frame, Chirp, Rx, Sample]、5维[Frame, Tx, Rx, Chirp, Sample]）
%   windowType   - 窗函数类型（数字/字符串均可，默认不加窗），支持：
%                  0/'none'    - 不加窗
%                  1/'hann'    - 汉宁窗（周期型）
%                  2/'hamming' - 汉明窗（周期型）
%                  3/'blackman'- 布莱克曼窗（周期型）
%   N            - FFT补零倍数（正整数，默认1，即不补零）
%   dopplerDim   - Doppler维度（即Chirp维度，默认第2维，可指定任意有效维度）
% 输出参数:
%   dopplerFFTData - 加窗+FFT+fftshift后的复数结果，维度与输入一致，仅Doppler维度长度变为DopplerLen*N

dataDims = size(mergedData);
numDims = length(dataDims);
DopplerLen = dataDims(dopplerDim);

if ischar(windowType) || isstring(windowType)
    switch lower(char(windowType))
        case {'none', 'no'}
            windowType = 0;
        case 'hann'
            windowType = 1;
        case 'hamming'
            windowType = 2;
        case 'blackman'
            windowType = 3;
        otherwise
            error('不支持的窗函数字符串：%s，支持：none/hann/hamming/blackman', windowType);
    end
end

flagNoWindow = (windowType == 0);
if ~flagNoWindow
    switch windowType
        case 1
            win = hann(DopplerLen, 'periodic');
        case 2
            win = hamming(DopplerLen, 'periodic');
        case 3
            win = blackman(DopplerLen, 'periodic');
        otherwise
            error('不支持的窗函数编号：%d，支持：0(无)/1(hann)/2(hamming)/3(blackman)', windowType);
    end

    winBaseShape = ones(1, numDims);
    winBaseShape(dopplerDim) = DopplerLen;
    winND_base = reshape(win, winBaseShape);
    repShape = dataDims;
    repShape(dopplerDim) = 1;
    winND = repmat(winND_base, repShape);
end

if flagNoWindow
    dopplerFFT = fft(mergedData, DopplerLen * N, dopplerDim);
    dopplerFFTData = fftshift(dopplerFFT, dopplerDim);
    disp('2d(Doppler) FFT done. (无窗函数)');
else
    windowedData = mergedData .* winND;
    dopplerFFT = fft(windowedData, DopplerLen * N, dopplerDim);
    dopplerFFTData = fftshift(dopplerFFT, dopplerDim);
    disp('2d(Doppler) FFT done. (已加窗)');
end

if iscolumn(dataDims)
    dataDims = dataDims';
end
outputDims = dataDims;
outputDims(dopplerDim) = DopplerLen * N;
dopplerFFTData = reshape(dopplerFFTData, outputDims);

end