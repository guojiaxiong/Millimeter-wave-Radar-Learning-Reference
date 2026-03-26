function targets = frame_dbscan(currentObservations, epsilon, minPoints) 
% slidingWindowClustering - 对单帧数据进行DBSCAN聚类并计算目标质心坐标
% 输入参数:
%   currentObservations - 所有帧的观测数据 [cfarIdx, x, y, vx, vy, range, theta]
%   epsilon - 邻域半径
%   minPoints - 形成簇的最小点数
% 输出参数:
%   targets - 目标参数 [cfarIdx, x, y, vx, vy]

% 如果没有观测点，返回空目标数组
if isempty(currentObservations)
    targets = [];
    return;
end

% 初始化结果数组
allTargets = [];

% 获取唯一的帧索引
allFrameIdx = unique(currentObservations(:, 1));

% 对每一帧数据进行处理
for frameIdx = 1:length(allFrameIdx)
    currentFrame = allFrameIdx(frameIdx);

    % 提取当前帧的观测数据（[cfarIdx, x, y, vx, vy]）
    currentFrameData = currentObservations(currentObservations(:, 1) == currentFrame, 1:5); 

    % 如果当前帧没有数据，跳过
    if isempty(currentFrameData)
        continue;
    end

    % 使用DBSCAN进行聚类（只对位置进行聚类）
    [clusterIndices, ~] = dbscan(currentFrameData(:, 2:3), epsilon, minPoints);

    % 找出有效的聚类（不包括噪声点）
    uniqueClusters = unique(clusterIndices);
    uniqueClusters = uniqueClusters(uniqueClusters ~= -1);  % 去除噪声点
    clusterCount = length(uniqueClusters);

    % 对每个聚类计算质心和平均速度
    for i = 1:clusterCount
        % 获取当前聚类的所有点
        clusterPoints = currentFrameData(clusterIndices == uniqueClusters(i), :);

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
