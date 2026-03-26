function rangeFFTData = fft2dwindow(mergedData, windowType, N)
% range_fft_with_window - 在D维加窗后进行FFT
%
% 输入:
%   rawData:     [FrameNum, ChirpNum, RxNum, SampleNum] 的原始复数数据
%   windowType:  使用的窗函数类型
%   DopplerFFT
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
        windowType = 9;  % 默认窗类型[0 1 2] = [hann hamming blackman]
    end

    [FrameNum, ChirpNum, RxNum, SampleNum] = size(mergedData);
    flag = 0;
    % 生成窗函数
    switch lower(windowType)
        case 1
            win = hann(ChirpNum);
        case 2
            win = hamming(ChirpNum);
        case 3
            win = blackman(ChirpNum);
        case 0
            flag = 1;
        otherwise
            error('Unsupported window type.');
    end

    % 初始化输出
    if flag 
        rangeFFTData = fftshift(fft(mergedData, ChirpNum * N, 2), 2); 
        disp('2dfft done.');
        return;
    end
    % 加窗并做FFT
    win4d = repmat(win, [1, RxNum, SampleNum, FrameNum]);
    win4d = permute(win4d, [4 1 2 3]);
    windowed = mergedData .* win4d;
    rangeFFTData = fftshift(fft(windowed, ChirpNum * N, 2), 2); 
    disp('2dfft done.');
end
