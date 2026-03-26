function [MTIData, Rmax] = MTIFilter(mergedData, alpha)
% applyMTIFilter 对 FMCW 雷达中频信号应用 MTI 滤波器
%
% 输入:
%   mergedData: 大小为 [FrameNum, ChirpNum, RxNum, SampleNum] 的数组
%   alpha: 平滑系数，0~1 之间，越大越敏感
%
% 输出:
%   r_filtered_all: MTI 滤波后的距离数据 [FrameNum, RxNum, SampleNum]
    [FrameNum, ~, RxNum, SampleNum] = size(mergedData);
    MTIData = zeros(FrameNum, RxNum, SampleNum);  % 存储滤波结果
    Rmax = zeros(FrameNum, RxNum, SampleNum);    % 存储数据
    for rxIdx = 1:RxNum
        t_prev = zeros(1, SampleNum);  % 初始化背景估计
        for frameIdx = 1:FrameNum
            frameData = squeeze(mergedData(frameIdx, :, rxIdx, :));
            rangeFFT = fft(frameData, [], 2);  % 距离维 FFT（沿 sample 维度）
            [~, maxIdx] = max(abs(rangeFFT), [], 1); 
            for r = 1:SampleNum
                Rmax(frameIdx, rxIdx, r) = frameData(maxIdx(r), r);
            end
            t_curr = alpha * squeeze(Rmax(frameIdx, rxIdx, :))' + (1 - alpha) * t_prev;      % 计算背景估计值
            r_filt = squeeze(Rmax(frameIdx, rxIdx, :))' - t_prev;  
            MTIData(frameIdx, rxIdx, :) = r_filt;
            t_prev = t_curr;                                    % 更新背景估计值
        end
    end
    disp('MTI done');
end

