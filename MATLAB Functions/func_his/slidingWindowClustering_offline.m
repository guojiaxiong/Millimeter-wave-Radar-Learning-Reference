function targets = slidingWindowClustering_offline(windowSize, currentObservations,epsilon,minPoints)
% slidingWindowClustering - 使用滑窗方式对多帧雷达数据进行聚类并计算目标参数
% 输入参数:
%   windowSize - 滑窗大小（帧数）
%   currentObservations - 所有帧的观测数据 [cfarIdx, x, y, vx, vy, range, theta]
%   epsilon = 0.5; % 邻域半径
%   minPoints = 5; % 形成簇的最小点数
% 输出参数:
%   targets - 目标参数 [cfarIdx, x, y, vx, vy]

% 使用DBSCAN算法进行聚类

% 如果没有观测点，返回空目标数组
if isempty(currentObservations)
    targets = [];
    return;
end

% 获取所有唯一的帧索引
allFrameIdx = unique(currentObservations(:, 1));
totalFrames = length(allFrameIdx);

% 初始化结果数组
allTargets = [];

% 对每一帧进行滑窗处理
for frameIdx = 1:totalFrames
    currentFrame = allFrameIdx(frameIdx);
    
    % 如果当前帧索引小于滑窗大小，跳过
    if currentFrame < windowSize
        continue;
    end
    
    % 确定滑窗范围
    windowStart = currentFrame - windowSize + 1;
    windowEnd = currentFrame;
    
    % 提取滑窗内的所有观测点
    windowMask = currentObservations(:, 1) >= windowStart & currentObservations(:, 1) <= windowEnd;
    windowObservations = currentObservations(windowMask, 1:5); % 提取 [cfarIdx, x, y, vx, vy]
    
    % 如果滑窗内没有观测点，跳过
    if isempty(windowObservations)
        continue;
    end
    
    % 使用DBSCAN进行聚类（只对位置信息进行聚类）
    [clusterIndices, ~] = dbscan(windowObservations(:, 2:3), epsilon, minPoints);
    
    % 找出有效的聚类（不包括噪声点）
    uniqueClusters = unique(clusterIndices);
    uniqueClusters = uniqueClusters(uniqueClusters ~= -1);
    clusterCount = length(uniqueClusters);
    
    % 对每个聚类计算质心和平均速度
    for i = 1:clusterCount
        % 获取当前聚类的所有点
        clusterPoints = windowObservations(clusterIndices == uniqueClusters(i), :);
        
        % 计算质心 (x, y)
        centerX = mean(clusterPoints(:, 2));
        centerY = mean(clusterPoints(:, 3));
        
        % 计算平均速度 (vx, vy)
        avgVx = mean(clusterPoints(:, 4));
        avgVy = mean(clusterPoints(:, 5));
        
        % 使用当前帧索引作为目标的帧索引
        targetCfar = currentFrame;
        
        % 存储目标参数 [cfarIdx, x, y, vx, vy]
        targetRow = [targetCfar, centerX, centerY, avgVx, avgVy];
        allTargets = [allTargets; targetRow];
    end
end

% 返回所有目标
targets = allTargets;
end