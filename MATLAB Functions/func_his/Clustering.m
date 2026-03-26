function cfarIdx = Clustering(dataNca, threshold)
    % dataNca: [FrameNum × ChirpNum × SampleNum]
    % threshold: dB 阈值
    % 输出 cfarIdx: [N × 3]，每一行为 [frameIdx, dopplerBin, rangeBin]

    [FrameNum, ~, ~] = size(dataNca);
    cfarIdx = [];

    for frameIdx = 1:FrameNum
        % 提取当前帧的 RD 图数据并加电平补偿
        X = db(squeeze(abs(dataNca(frameIdx,:,:))));  % [chirpNum × sampleNum]
        powerad = linspace(0, 8, size(X, 2));
        powerad2d = repmat(powerad, [size(X, 1), 1]);
        X = X + powerad2d;

        % 提取高能量点
        [rowIdx, colIdx] = find(X > threshold);
        points = [rowIdx, colIdx];

        if isempty(points)
            continue
        end

        % DBSCAN 聚类
        epsilon = 5;
        minPts = 4;
        labels = dbscan(points, epsilon, minPts);
        uniqueLabels = unique(labels);

        % 遍历聚类标签，提取聚类中心
        for i = 1:length(uniqueLabels)
            label = uniqueLabels(i);
            if label == -1
                continue  % 忽略噪声
            end
            clusterPoints = points(labels == label, :);
            if ~isempty(clusterPoints)
                center = mean(clusterPoints, 1);  % [rangeBin, dopplerBin]
                cfarIdx = [cfarIdx; frameIdx, round(center(1)), round(center(2))];
            end
        end
    end
    disp('Clustering done.');
end

% single frame
% frameIdx =125
% % 阈值过滤
% threshold = 100;  % dB 阈值，可根据数据调整
% X = db(squeeze(abs(dataNca(frameIdx,:,:))));  % 提取帧数据并转换为 dB
% 
% % 
% powerad = linspace(0, 8 ,size(X, 2));
% powerad2d = repmat(powerad, [size(X, 1), 1]);
% X = X + powerad2d;
% 
% [rowIdx, colIdx] = find(X > threshold);  % 找出高能量点
% points = [rowIdx, colIdx];  % DBSCAN 输入 [rangeBin, dopplerBin]
% 
% % DBSCAN 参数
% epsilon = 5;  % 邻域半径
% minPts = 4;   % 最小簇内点数
% 
% % 执行 DBSCAN 聚类
% labels = dbscan(points, epsilon, minPts);
% uniqueLabels = unique(labels);
% numGroups = length(uniqueLabels);
% 
% % 可视化 RD 图和聚类结果
% figure;
% imagesc(X); 
% colormap('jet'); 
% colorbar;
% hold on;
% title(sprintf('RD Map with Clusters (Threshold > %d dB)', threshold));
% xlabel('Doppler Bin');
% ylabel('Range Bin');
% 
% % 画出所有高能量点（黑点）
% plot(points(:,2), points(:,1), 'k.', 'MarkerSize', 8);  % 注意：列是 x，行为 y
% 
% % 为不同聚类使用不同颜色标出并画出聚类中心
% colors = lines(numGroups);
% for i = 1:numGroups
%     label = uniqueLabels(i);
%     if label == -1
%         continue  % 忽略噪声点
%     end
%     clusterPoints = points(labels == label, :);
%     if ~isempty(clusterPoints)
%         % 标出聚类点
%         plot(clusterPoints(:,2), clusterPoints(:,1), '.', 'Color', colors(i,:), 'MarkerSize', 12);
% 
%         % 计算并标注聚类中心
%         center = mean(clusterPoints, 1);  % [rangeBin, dopplerBin]
%         plot(center(2), center(1), 'ko', 'MarkerSize', 10, 'LineWidth', 2);  % 白圈为中心点
%         text(center(2)+1, center(1), sprintf('C%d', label), 'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');
%     end
% end
% 
% axis xy;  % 保证图像方向正确（y 向下为 range，x 为 Doppler）
