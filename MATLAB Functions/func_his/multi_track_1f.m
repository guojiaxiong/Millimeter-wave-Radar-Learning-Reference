function currenttracks = multi_track_1f(detections, reset)
    
    %detections是每帧数据点的坐标，n×2数组，reset是重置键，1清零重置，0正常跟踪
    persistent tracks nextId recentDets
    dt = 0.5;                   % 时间步长
    costThreshold = 0.8;        % 关联阈值
    processNoise = 0.4;         % 过程噪声
    measurementNoise = 0.4;     % 测量噪声

    % Kalman滤波器参数 (预计算常量)
    F = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1]; % 状态转移
    H = [1 0 0 0; 0 1 0 0];                     % 观测矩阵
    Q_base = [dt^3/3 0 dt^2/2 0;
             0 dt^3/3 0 dt^2/2;
             dt^2/2 0 dt 0;
             0 dt^2/2 0 dt];                    % 过程噪声协方差基
    R = measurementNoise^2 * eye(2);            % 观测噪声协方差
    
    % 初始化检查
    if isempty(tracks) || reset
        tracks = struct('id', {}, 'x', {}, 'P', {}, 'age', {}, ...
                    'totalVisibleCount', {}, 'consecutiveInvisibleCount', {}, ...
                    'history', {});
        nextId = 1;
        recentDets = {};  % 重置历史检测点
    end

    % ===== 单帧处理 =====
    %% 步骤1: 预测现有轨迹 
    numTrks = length(tracks);
    if numTrks > 0
        % 预分配速度向量
        speeds = zeros(1, numTrks);
        activeTrks = true(1, numTrks); % 标记活动轨迹
        
        % 并行计算速度和活动状态
        for i = 1:numTrks
            if tracks(i).consecutiveInvisibleCount >= 3
                % 休眠轨迹不更新
                activeTrks(i) = false;
                tracks(i).age = tracks(i).age + 1;
                tracks(i).consecutiveInvisibleCount = tracks(i).consecutiveInvisibleCount + 1;
            else
                speeds(i) = norm(tracks(i).x(3:4));
            end
        end
        
        % 只处理活动轨迹
        activeIdx = find(activeTrks);
        for i = activeIdx
            % 动态噪声调整 (基于速度)
            adaptiveQ = processNoise * (1 + 0.1*speeds(i)) * Q_base;
            
            % Kalman预测
            tracks(i).x = F * tracks(i).x;
            tracks(i).P = F * tracks(i).P * F' + adaptiveQ;
            tracks(i).age = tracks(i).age + 1;
            tracks(i).consecutiveInvisibleCount = tracks(i).consecutiveInvisibleCount + 1;
        end
    end
    
    %% 步骤2: 高效数据关联
    currentDets = detections;  % 当前帧检测点
    numDets = size(currentDets, 1);
    
%     % 快速返回无轨迹情况
%     if numTrks == 0 || numDets == 0
%         assignments = [];
%         unTrks = 1:numTrks;
%         unDets = 1:numDets;
% %         gotoInitNewTracks; % 跳转到新轨迹初始化
%     end
    
    % 构建马氏距离成本矩阵 (向量化优化)
    cost = inf(numTrks, numDets);
    gateThreshold = chi2inv(0.9, 2);  % 门限阈值 (自由度为2)
    
    % 预计算所有轨迹的预测位置和S矩阵
    predPos = zeros(2, numTrks);
    S_all = zeros(2, 2, numTrks);
    for i = 1:numTrks
        predPos(:, i) = H * tracks(i).x;
        S_all(:, :, i) = H * tracks(i).P * H' + R;
    end
    
    % 向量化计算距离
    for d = 1:numDets
        dZ = currentDets(d, :)' - predPos; % [2xN]矩阵
        for t = 1:numTrks
            % 使用更稳定的线性求解代替逆矩阵
            dZd = dZ(:, t);
            S = S_all(:, :, t);
            mahalanobisDist = sqrt(dZd' / S * dZd);
            if mahalanobisDist <= gateThreshold
                cost(t, d) = mahalanobisDist;
            end
        end
    end
    
    % 快速关联 (使用内置matchpairs)
    cost(cost > costThreshold) = inf;
    if all(isinf(cost(:)))
        assignments = [];
        unTrks = 1:numTrks;
        unDets = 1:numDets;
    else
        [assignments, unTrks, unDets] = matchpairs(cost, costThreshold, 'min');
    end
    
    %% 步骤3: 更新匹配轨迹
    for a = 1:size(assignments, 1)
        trkIdx = assignments(a, 1);
        detIdx = assignments(a, 2);
        z = currentDets(detIdx, :)';
        
        % Kalman更新 (使用预计算的S矩阵)
        S = S_all(:, :, trkIdx);
        K = tracks(trkIdx).P * H' / S;
        y = z - predPos(:, trkIdx);
        tracks(trkIdx).x = tracks(trkIdx).x + K * y;
        tracks(trkIdx).P = (eye(4) - K * H) * tracks(trkIdx).P;
        
        % 更新轨迹状态
        tracks(trkIdx).totalVisibleCount = tracks(trkIdx).totalVisibleCount + 1;
        tracks(trkIdx).consecutiveInvisibleCount = 0;
    end
    
    %% 步骤4: 高效新轨迹初始化
%     InitNewTracks:
    proximityThreshold = 0.5;  % 邻近点阈值
    minInitialHits = 2;        % 降低连续出现要求
    
    % 获取已匹配点坐标 (用于邻近检测)
    matchedPoints = [];
    if ~isempty(assignments)
        matchedPoints = currentDets(assignments(:, 2), :);
    end
    
    % 特殊处理第一帧
    if isempty(tracks) || isempty(recentDets)
        newTracks = cell(1, numDets);
        newCount = 0;
        for d = 1:numDets
            detPos = currentDets(d, :)';
            newCount = newCount + 1;
            newTracks{newCount} = struct(...
                'id', nextId, ...
                'x', [detPos; 0; 0], ...
                'P', diag([R(1,1), R(2,2), 100, 100]), ...
                'age', 1, ...
                'totalVisibleCount', 1, ...
                'consecutiveInvisibleCount', 0, ...
                'history', detPos');
            nextId = nextId + 1;
        end
        tracks = [tracks, [newTracks{1:newCount}]];
    else
        % 正常帧处理 - 只处理未匹配点
        unDetsPoints = currentDets(unDets, :);
        numUnDets = size(unDetsPoints, 1);
        
        % 快速邻近点检查
        isNearMatched = false(1, numUnDets);
        if ~isempty(matchedPoints) && numUnDets > 0
            dists = pdist2(unDetsPoints, matchedPoints);
            isNearMatched = any(dists < proximityThreshold, 2);
        end
        
        % 历史一致性检查 (使用最近2帧)
        consistentCounts = zeros(numUnDets, 1);
        for j = 1:min(2, length(recentDets))
            prevDets = recentDets{end-j+1};
            if ~isempty(prevDets) && numUnDets > 0
                dists = pdist2(unDetsPoints, prevDets);
                consistentCounts = consistentCounts + any(dists < costThreshold, 2);
            end
        end
        
        % 创建新轨迹
        newTracks = cell(1, numUnDets);
        newCount = 0;
        for d = 1:numUnDets
            if ~isNearMatched(d) && consistentCounts(d) >= minInitialHits - 1
                detPos = unDetsPoints(d, :)';
                newCount = newCount + 1;
                newTracks{newCount} = struct(...
                    'id', nextId, ...
                    'x', [detPos; 0; 0], ...
                    'P', diag([R(1,1), R(2,2), 100, 100]), ...
                    'age', 1, ...
                    'totalVisibleCount', 1, ...
                    'consecutiveInvisibleCount', 0, ...
                    'history', detPos');
                nextId = nextId + 1;
            end
        end
        tracks = [tracks, [newTracks{1:newCount}]];
    end
    
    %% 步骤5: 更新历史轨迹 
    for i = 1:length(tracks)
        tracks(i).history = [tracks(i).history; tracks(i).x(1:2)'];
    end
    
    %% 步骤6: 管理历史检测点 (保存最近3帧)
    recentDets = [recentDets, {currentDets}];
    if length(recentDets) > 3
        recentDets(1) = [];
    end
    currenttracks = tracks;
%     %% 步骤7: 删除丢失的轨迹 (快速批量操作)
%     maxInvisibleCount = 10;
%     minVisibleCount = 5;
%     toDelete = false(1, length(tracks));
%     
%     for i = 1:length(tracks)
%         if tracks(i).consecutiveInvisibleCount > maxInvisibleCount || ...
%            tracks(i).totalVisibleCount < minVisibleCount
%             toDelete(i) = true;
%         end
%     end
%     tracks(toDelete) = [];
%     
    % 返回当前轨迹
end