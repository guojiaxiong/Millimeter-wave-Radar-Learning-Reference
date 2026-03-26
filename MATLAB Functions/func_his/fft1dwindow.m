function rangeFFTData = fft1dwindow(mergedData, windowType, N)
% range_fft_with_window - 在R维加窗后进行FFT
%
% 输入:
%   rawData:     [FrameNum, ChirpNum, RxNum, SampleNum] 的原始复数数据
%   windowType:  使用的窗函数类型
%
% rangeFFT
%     编号    加窗方法
%     ____    __________
%      0      no
%      1      hann
%      2      hamming
%      3      blackman
%
% 输出:
%   rangeFFTData: 加窗并做FFT后的复数结果，维度与输入一致

    if nargin < 2
        windowType = 0;  % 默认窗类型[0 1 2] = [hann hamming blackman]
    end

    [FrameNum, ChirpNum, RxNum, SampleNum] = size(mergedData);
    flag = 0;
    % 生成窗函数
    switch lower(windowType)
        case 1
            win = hann(SampleNum);
        case 2
            win = hamming(SampleNum);
        case 3
            win = blackman(SampleNum);
        case 0
            flag = 1;
        otherwise
            error('Unsupported window type.');
    end

    % 初始化输出
    if flag 
        rangeFFTData = (fft(mergedData, SampleNum * N, 4));
        disp('1dfft done.');
        return;
    end
    win4d = repmat(win, [1, RxNum, ChirpNum, FrameNum]);
    win4d = permute(win4d, [4 3 2 1]);
    windowed = mergedData .* win4d;
    rangeFFTData = fft(windowed, SampleNum * N, 4);  
    disp('1dfft done.');
end
