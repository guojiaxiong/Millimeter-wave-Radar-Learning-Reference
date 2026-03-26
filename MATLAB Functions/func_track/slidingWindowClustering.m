function targets = slidingWindowClustering(windowSize, currentFrameIdx, currentObservations,epsilon,minPoints)
% slidingWindowClustering - 使用滑窗方式对多帧雷达数据进行聚类并计算目标参数
% 输入参数:
%   windowSize - 滑窗大小（帧数）
%   currentFrameIdx - 当前帧索引
%   currentObservations - 当前帧的观测数据 [cfarIdx, x, y, vx, vy, range, theta]
%   epsilon = 0.5; % 邻域半径
%   minPoints = 5; % 形成簇的最小点数
% 输出参数:
%   targets - 目标参数 [1, x, y, vx, vy]

% 定义持久变量，用于存储滑窗内的观测数据
persistent frameBuffer;
% 使用DBSCAN算法进行聚类

% 初始化帧缓冲区（如果为空）
if isempty(frameBuffer)
    frameBuffer = cell(1, windowSize);
end

% 更新帧缓冲区
frameBuffer{mod(currentFrameIdx-1, windowSize) + 1} = currentObservations;

% 如果当前帧索引小于滑窗大小，说明还没有收集足够的帧
if currentFrameIdx < windowSize
    % 返回空目标数组
    targets = [];
    return;
end

% 合并滑窗内的所有观测点
allObservations = [];
for i = 1:windowSize
    if ~isempty(frameBuffer{i})
        % 提取所有信息 (cfarIdx, x, y, vx, vy)
        frameData = frameBuffer{i}(:, 1:7);
        allObservations = [allObservations; frameData];
    end
end

% 如果没有观测点，返回空目标数组
if isempty(allObservations)
    targets = [];
    return;
end

allObservations = mutlpathfilt(allObservations, p);

[clusterIndices, ~] = dbscan(allObservations(:, 2:3), epsilon, minPoints);

% 找出有效的聚类（不包括噪声点，噪声点的clusterIndices为-1）
uniqueClusters = unique(clusterIndices);
uniqueClusters = uniqueClusters(uniqueClusters ~= -1);
clusterCount = length(uniqueClusters);

% 初始化目标数组
targets = zeros(clusterCount, 5);

% 对每个聚类计算质心和平均速度
for i = 1:clusterCount
    % 获取当前聚类的所有点
    clusterPoints = allObservations(clusterIndices == uniqueClusters(i), :);
    
    % 计算质心 (x, y)
    centerX = mean(clusterPoints(:, 2));
    centerY = mean(clusterPoints(:, 3));
    
    % 计算平均速度 (vx, vy)
    avgVx = mean(clusterPoints(:, 4));
    avgVy = mean(clusterPoints(:, 5));
    
    
    % 存储目标参数 [cfarIdx, x, y, vx, vy]
    targets(i, :) = [1, centerX, centerY, avgVx, avgVy];
end
end