function mergedData = mergeCells(rx0, rx1)
    %数据整理
    frameNum = size(rx0, 1);
    chirpNum = size(rx0, 2);
    sampleNum = size(rx0{1,1}, 1); % 取第一个cell的数据长度
    
    % 初始化目标数组
    % 注意顺序：[Frame, Chirp, Antenna, Sample]
    mergedData = zeros(frameNum, chirpNum, 2, sampleNum);
    
    % 填充数据
    for frameIdx = 1:frameNum
        for chirpIdx = 1:chirpNum
            mergedData(frameIdx, chirpIdx, 1, :) = rx0{frameIdx, chirpIdx}; % 天线 0
            mergedData(frameIdx, chirpIdx, 2, :) = rx1{frameIdx, chirpIdx}; % 天线 1
        end
    end
end