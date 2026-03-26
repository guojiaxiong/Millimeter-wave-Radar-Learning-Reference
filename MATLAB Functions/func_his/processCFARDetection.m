function cfarIdx = processCFARDetection(N_target, suppressWin, energyThresh, epsilon, minPts, dataNca)
% 获取数据维度
[FrameNum, ~, ~] = size(dataNca);  % 获取帧数
cfarIdx = [];  % 用于存储所有帧的目标坐标

for frameIdx = 1:FrameNum
    % 提取该帧的 RD 图 [velocity x range]
    RD_map = abs(squeeze(dataNca(frameIdx, :, :)));  % [V, R]

    % 检测当前帧的前 N 个目标
    [targetList, ~] = detectTopNTargets(RD_map, N_target, suppressWin, frameIdx, energyThresh);

    % 如果没有目标，跳过当前帧，开始下一帧
    if isempty(targetList)
        continue;
    end

    % 提取目标点的 vIdx 和 rIdx
    points = targetList(:, 1:2);  % [vIdx, rIdx]

    % 使用 DBSCAN 进行聚类
    [idx, ~] = dbscan(points, epsilon, minPts);

    % 计算每个簇的质心
    centroids = [];  % 存储每个簇的质心
    for i = 1:max(idx)
        clusterPoints = points(idx == i, :);
        centroid_vIdx = round(mean(clusterPoints(:, 1)));  % 计算速度索引的质心
        centroid_rIdx = round(mean(clusterPoints(:, 2)));  % 计算距离索引的质心
        centroids = [centroids; centroid_vIdx, centroid_rIdx];
    end

    % 将质心存储到 cfarIdx 中
    for j = 1:size(centroids, 1)
        cfarIdx = [cfarIdx; frameIdx, centroids(j, 1), centroids(j, 2)];  % 存储 [frameIdx, vIdx, rIdx]
    end
end
end
