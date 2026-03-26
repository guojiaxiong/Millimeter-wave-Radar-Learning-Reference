function mtiOutput = mti_max_filter(fftData, alpha)
% data: [FrameNum, ChirpNum, RxNum, SampleNum]
% alpha: smoothing factor
% mtiOutput: [FrameNum, SampleNum]

[FrameNum, ChirpNum, RxNum, SampleNum] = size(fftData);
mtiOutput = zeros(FrameNum, SampleNum);
ti_prev = zeros(1, SampleNum); % 初始 ti−1 为 0

for frameIdx = 1:FrameNum
    % 合并所有chirp和天线，求每个sample的最大值
    maxPerSample = zeros(1, SampleNum);
    for chirpIdx = 1:ChirpNum
        for rxIdx = 1:RxNum
            sig = squeeze(fftData(frameIdx, chirpIdx, rxIdx, :));
            maxPerSample = max(maxPerSample, abs(sig)');
        end
    end

    % α滤波器： ti = α·ri + (1−α)·ti−1
    ti = alpha * maxPerSample + (1 - alpha) * ti_prev;

    % MTI输出 = abs(当前最大值 − 上一帧滤波值)
    mtiOutput(frameIdx, :) = abs(maxPerSample - ti_prev);

    % 更新 ti_prev
    ti_prev = ti;
end

end
