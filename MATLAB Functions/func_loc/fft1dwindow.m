function rangeFFTData = fft1dwindow(mergedData, windowType, N, rangeDim)
% FFT1DWINDOW 通用型1D FFT加窗函数（适配雷达多维数据）
% 用法:
%   rangeFFTData = fft1dwindow(mergedData, windowType, N, dim)
% 输入参数:
%   mergedData   - 任意维度的雷达原始复数数据（如4维[Frame, Rx, Chirp, Sample]、5维[Frame, Tx, Rx, Chirp, Sample]）
%   windowType   - 窗函数类型（数字/字符串均可），支持：
%                  0/'none'    - 不加窗
%                  1/'hann'    - 汉宁窗（周期型）
%                  2/'hamming' - 汉明窗（周期型）
%                  3/'blackman'- 布莱克曼窗（周期型）
%   N            - FFT补零倍数（正整数，默认1，即不补零）
%   dim          - 执行FFT的目标维度（如Sample维度，必填）
% 输出参数:
%   rangeFFTData - 加窗并做FFT后的复数结果，维度与输入一致，仅目标维度长度变为SampleNum*N

dataDims = size(mergedData);
numDims  = length(dataDims);
SampleNum = dataDims(rangeDim);

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
            win = hann(SampleNum, 'periodic');
        case 2
            win = hamming(SampleNum, 'periodic');
        case 3
            win = blackman(SampleNum, 'periodic');
        otherwise
            error('不支持的窗函数编号：%d，支持：0(无)/1(hann)/2(hamming)/3(blackman)', windowType);
    end
    winBaseShape = ones(1, numDims);
    winBaseShape(rangeDim) = SampleNum;
    winND_base = reshape(win, winBaseShape);
    wind1 = dataDims;
    wind1(rangeDim) = [];
    winND = repmat(winND_base, wind1);
end

if flagNoWindow
    rangeFFTData = fft(mergedData, SampleNum * N, rangeDim);
    disp('1dfft done. (无窗函数)');
else
    windowedData = mergedData .* winND;
    rangeFFTData = fft(windowedData, SampleNum * N, rangeDim);
    disp('1dfft done. (已加窗)');
end

if iscolumn(dataDims)
    dataDims = dataDims';
end
outputDims = dataDims;
outputDims(rangeDim) = SampleNum * N;
rangeFFTData = reshape(rangeFFTData, outputDims);

end