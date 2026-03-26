function current_points = tracks_ultra(detections, costThreshold, predictionframe, reset)
    % 输入参数:
    %   detections - 当前帧检测数据 (n×4数组: [x, y, vx, vy])
    %   reset - 重置标志 (1=重置跟踪器, 0=正常跟踪)
    
    persistent tracks nextId recentDets stateHistories dirHistories

    % 参数
    dt = 0.1;                                          %帧时间
    processNoise = 0.4;                       % 过程噪声
    measurementNoise = 0.5;             % 测量噪声
    gateThreshold = chi2inv(0.90, 4);  % 门限阈值
    proximityThreshold = 1;              % 邻近点阈值 
    minInitialHits = 3;                            % 最小初始匹配次数
    maxInvisibleCount = 20;                 %最大不可见 变
    minVisibleCount = 5;                       %最小可见 越大越碎5
    clusterThreshold = 1.5;     %第一帧点的距离阈值
    
    % ===== 新增参数 =====
    dirWeight = 0.8;             % 方向权重 (0-1)
    turnThreshold = 30;         % 转弯检测阈值(度/帧)
    minSpeedForDir = 0.02;      % 应用方向约束的最小速度
    % ===================
    
    % Kalman滤波器参数 (4维状态和观测)
    F = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1]; % 状态转移
    H = eye(4);                                               % 观测矩阵 
    Q_base = [dt^3/3 0 dt^2/2 0;
             0 dt^3/3 0 dt^2/2;
             dt^2/2 0 dt 0;
             0 dt^2/2 0 dt];                                % 过程噪声协方差基
    R = measurementNoise^2 * eye(4);      % 观测噪声协方差 
    
    % 初始化检查
    if isempty(tracks) || reset
        tracks = struct('id', {}, 'x', {}, 'P', {}, 'age', {}, ...
                    'totalVisibleCount', {}, 'consecutiveInvisibleCount', {}, ...
                    'history', {}, 'dirChangeRate', {});
        stateHistories = {};  % 状态历史缓存
        dirHistories = {};    % 新增：方向历史缓存
        nextId = 1;
        recentDets = {};  % 重置历史检测点
    end

    % ===== 单帧处理 =====
    % 步骤1: 预测现有轨迹 (使用历史信息改进预测)
    numTrks = length(tracks);
    if numTrks > 0
        % 预分配速度向量
        speeds = zeros(1, numTrks);
        activeTrks = true(1, numTrks); % 标记活动轨迹
        
        % 更新状态历史和方向历史
        for i = 1:numTrks
            % 确保状态历史缓存存在
            if length(stateHistories) < i
                stateHistories{i} = [];
                dirHistories{i} = []; % 初始化方向历史
            end
            
            % 添加当前状态到历史
            stateHistories{i} = [stateHistories{i}, tracks(i).x];
            
            % 计算当前方向并添加到方向历史
            currentVel = tracks(i).x(3:4);
            if norm(currentVel) > 0.1
                currentDir = atan2d(currentVel(2), currentVel(1)); % 角度制
                dirHistories{i} = [dirHistories{i}, currentDir];
            else
                dirHistories{i} = [dirHistories{i}, NaN];
            end
            
            % 保持指定长度的历史
            if size(stateHistories{i}, 2) > predictionframe
                stateHistories{i} = stateHistories{i}(:, end-predictionframe+1:end);
            end
            if length(dirHistories{i}) > predictionframe
                dirHistories{i} = dirHistories{i}(end-predictionframe+1:end);
            end
        end
        
        % 处理轨迹
        for i = 1:numTrks
            if tracks(i).consecutiveInvisibleCount >= 3
                % 休眠轨迹不更新
                activeTrks(i) = false;
                tracks(i).age = tracks(i).age + 1;
                tracks(i).consecutiveInvisibleCount = tracks(i).consecutiveInvisibleCount + 1;
            else
                % 计算基于历史的速度
                if size(stateHistories{i}, 2) > 1
                    % 使用历史状态计算平均速度
                    histVelocities = stateHistories{i}(3:4, :);
                    avgVelocity = mean(histVelocities, 2);
                    speeds(i) = norm(avgVelocity);
                else
                    % 没有足够历史，使用当前速度
                    speeds(i) = norm(tracks(i).x(3:4));
                end
            end
            
            % ===== 新增：计算方向变化率 =====
            validDirs = dirHistories{i}(~isnan(dirHistories{i}));
            if length(validDirs) >= 2
                dirDiffs = diff(validDirs);
                % 处理角度跳变
                dirDiffs = mod(dirDiffs + 180, 360) - 180;
                tracks(i).dirChangeRate = mean(abs(dirDiffs))/dt;
            else
                tracks(i).dirChangeRate = 0;
            end
            % =============================
        end
        
        % 只处理活动轨迹
        activeIdx = find(activeTrks);
        for i = activeIdx
            % 动态噪声调整 (基于速度)
            adaptiveQ = processNoise * (1 + 0.1*speeds(i)) * Q_base;
            
            % 使用历史信息改进预测
            if size(stateHistories{i}, 2) >= 2
                % 计算基于历史的速度趋势
                histStates = stateHistories{i};
                timeSteps = size(histStates, 2);
                
                % 计算位置和速度的变化率
                posDeltas = diff(histStates(1:2, :), 1, 2);
                velDeltas = diff(histStates(3:4, :), 1, 2);
                
                % 计算平均变化率
                avgPosDelta = mean(posDeltas, 2) / dt;
                avgVelDelta = mean(velDeltas, 2) / dt;
                
                % 创建改进的状态向量
                improvedState = tracks(i).x;
                improvedState(1:2) = improvedState(1:2) + avgPosDelta * dt;
                improvedState(3:4) = improvedState(3:4) + avgVelDelta * dt;
                
                % 使用改进的状态进行预测
                tracks(i).x = F * improvedState;
            else
                % 没有足够历史，使用标准预测
                tracks(i).x = F * tracks(i).x;
            end
            
            % 更新协方差
            tracks(i).P = F * tracks(i).P * F' + adaptiveQ;
            tracks(i).age = tracks(i).age + 1;
            tracks(i).consecutiveInvisibleCount = tracks(i).consecutiveInvisibleCount + 1;
        end
    end
    
    % 步骤2: 增强数据关联（方向约束）
    currentDets = detections;  % 当前帧检测点 [x, y, vx, vy]
    numDets = size(currentDets, 1);
    
    % 构建马氏距离成本矩阵 (向量化优化)
    cost = inf(numTrks, numDets);
    
    % 预计算所有轨迹的预测状态和S矩阵
    predStates = zeros(4, numTrks);
    S_all = zeros(4, 4, numTrks);
    for i = 1:numTrks
        predStates(:, i) = H * tracks(i).x;
        S_all(:, :, i) = H * tracks(i).P * H' + R;
    end
    
    % 向量化计算距离
    for d = 1:numDets
        dZ = currentDets(d, :)' - predStates; % [4xN]矩阵
        for t = 1:numTrks
            % 计算马氏距离
            dZd = dZ(:, t);
            S = S_all(:, :, t);
            mahalanobisDist = sqrt(dZd' / S * dZd);
            
            % ===== 新增：方向一致性约束 =====
            if mahalanobisDist <= gateThreshold
                % 仅当速度足够大时应用方向约束
                predSpeed = norm(predStates(3:4, t));
                detSpeed = norm(currentDets(d, 3:4));
                
                if predSpeed > minSpeedForDir && detSpeed > minSpeedForDir
                    % 计算预测方向和检测方向
                    predDir = atan2d(predStates(4, t), predStates(3, t));
                    detDir = atan2d(currentDets(d, 4), currentDets(d, 3));
                    
                    % 计算角度差 (考虑圆周性)
                    angleDiff = abs(mod(predDir - detDir + 180, 360) - 180);
                    
                    % 根据方向变化率调整约束强度
                    if tracks(t).dirChangeRate < turnThreshold
                        % 直线运动：强方向约束
                        dirPenalty = dirWeight * (angleDiff / 180);
                    else
                        % 转弯运动：弱方向约束
                        dirPenalty = (dirWeight / 3) * (angleDiff / 180);
                    end
                    
                    % 组合马氏距离和方向惩罚
                    combinedCost = (1 - dirWeight) * mahalanobisDist + ...
                                   dirWeight * dirPenalty * costThreshold;
                    cost(t, d) = combinedCost;
                else
                    % 速度太小，不使用方向约束
                    cost(t, d) = mahalanobisDist;
                end
            end
            % =============================
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
    
    % 步骤3: 更新匹配轨迹
    for a = 1:size(assignments, 1)
        trkIdx = assignments(a, 1);
        detIdx = assignments(a, 2);
        z = currentDets(detIdx, :)';
        
        % Kalman更新 (使用预计算的S矩阵)
        S = S_all(:, :, trkIdx);
        K = tracks(trkIdx).P * H' / S;
        y = z - predStates(:, trkIdx);
        tracks(trkIdx).x = tracks(trkIdx).x + K * y;
        tracks(trkIdx).P = (eye(4) - K * H) * tracks(trkIdx).P;
        
        % 更新轨迹状态
        tracks(trkIdx).totalVisibleCount = tracks(trkIdx).totalVisibleCount + 1;
        tracks(trkIdx).consecutiveInvisibleCount = 0;
        
        % 更新状态历史
        if length(stateHistories) < trkIdx
            stateHistories{trkIdx} = [];
            dirHistories{trkIdx} = [];
        end
        stateHistories{trkIdx} = [stateHistories{trkIdx}, tracks(trkIdx).x];
        if size(stateHistories{trkIdx}, 2) > predictionframe
            stateHistories{trkIdx} = stateHistories{trkIdx}(:, end-predictionframe+1:end);
        end
    end
    
    % 步骤4: 高效新轨迹初始化
    % 获取已匹配点坐标 (用于邻近检测)
    matchedPoints = [];
    if ~isempty(assignments)
        matchedPoints = currentDets(assignments(:, 2), :);
    end
    
    % 特殊处理第一帧
    if isempty(tracks) || isempty(recentDets)
        % ====== 简单点合并策略 ======
        mergedPoints = [];  % 存储合并后的点
        merged = false(1, numDets);  % 标记已合并的点
        
        % 检查所有点对
        for i = 1:numDets
            if merged(i), continue; end  % 跳过已合并的点
            
            for j = (i+1):numDets
                if merged(j), continue; end  % 跳过已合并的点
                
                % 计算两点间距离 (仅位置)
                dist = norm(currentDets(i, 1:2) - currentDets(j, 1:2));
                
                % 如果距离小于阈值，合并两点
                if dist < clusterThreshold
                    % 计算合并点 (位置和速度取平均)
                    mergedPoint = (currentDets(i, :) + currentDets(j, :)) / 2;
                    mergedPoints = [mergedPoints; mergedPoint];
                    
                    % 标记两点已合并
                    merged(i) = true;
                    merged(j) = true;
                    break;  % 找到匹配后跳出内层循环
                end
            end
            
            % 如果没有找到匹配点，单独处理
            if ~merged(i)
                mergedPoints = [mergedPoints; currentDets(i, :)];
                merged(i) = true;
            end
        end
        
        % 为每个合并点创建轨迹
        newTracks = cell(1, size(mergedPoints, 1));
        newCount = 0;
        for p = 1:size(mergedPoints, 1)
            detState = mergedPoints(p, :)';  % 状态向量 [x; y; vx; vy]
            newCount = newCount + 1;
            newTracks{newCount} = struct(...
                'id', nextId, ...
                'x', detState, ...
                'P', diag([R(1,1), R(2,2), R(3,3), R(4,4)]), ...
                'age', 1, ...
                'totalVisibleCount', 1, ...
                'consecutiveInvisibleCount', 0, ...
                'history', detState(1:2)', ...
                'dirChangeRate', 0); % 初始化方向变化率
            nextId = nextId + 1;
            
            % 初始化状态历史
            stateHistories{end+1} = detState;
            dirHistories{end+1} = atan2d(detState(4), detState(3)); % 初始方向
        end
        tracks = [tracks, [newTracks{1:newCount}]];
    else
        % 正常帧处理 - 只处理未匹配点
        unDetsPoints = currentDets(unDets, :);
        numUnDets = size(unDetsPoints, 1);
        
        % 快速邻近点检查 (基于位置)
        isNearMatched = false(1, numUnDets);
        if ~isempty(matchedPoints) && numUnDets > 0
            % 只比较位置 (x,y)
            posDists = pdist2(unDetsPoints(:, 1:2), matchedPoints(:, 1:2));
            isNearMatched = any(posDists < proximityThreshold, 2);
        end
        
        % 历史一致性检查 (使用最近2帧的位置)
        consistentCounts = zeros(numUnDets, 1);
        for j = 1:min(2, length(recentDets))
            prevDets = recentDets{end-j+1};
            if ~isempty(prevDets) && numUnDets > 0
                % 只比较位置 (x,y)
                posDists = pdist2(unDetsPoints(:, 1:2), prevDets(:, 1:2));
                consistentCounts = consistentCounts + any(posDists < costThreshold, 2);
            end
        end
        
        % 创建新轨迹
        newTracks = cell(1, numUnDets);
        newCount = 0;
        for d = 1:numUnDets
            if ~isNearMatched(d) && consistentCounts(d) >= minInitialHits - 1
                detState = unDetsPoints(d, :)';  % 获取完整状态 [x; y; vx; vy]
                newCount = newCount + 1;
                newTracks{newCount} = struct(...
                    'id', nextId, ...
                    'x', detState, ...  % 使用检测到的速度初始化
                    'P', diag([R(1,1), R(2,2), R(3,3), R(4,4)]), ... % 初始协方差
                    'age', 1, ...
                    'totalVisibleCount', 1, ...
                    'consecutiveInvisibleCount', 0, ...
                    'history', detState(1:2)', ... % 历史只记录位置
                    'dirChangeRate', 0); % 初始化方向变化率
                nextId = nextId + 1;
                
                % 初始化状态历史
                stateHistories{length(tracks) + newCount} = detState;
                dirHistories{length(tracks) + newCount} = atan2d(detState(4), detState(3)); % 初始方向
            end
        end
        if newCount > 0
            tracks = [tracks, [newTracks{1:newCount}]];
        end
    end
    
    % 步骤5: 更新历史轨迹 
    for i = 1:length(tracks)
        % 只记录位置历史 (x,y)
        tracks(i).history = [tracks(i).history; tracks(i).x(1:2)'];
    end
    
    % 步骤6: 管理历史检测点 (保存最近3帧)
    recentDets = [recentDets, {currentDets}];
    if length(recentDets) > 3
        recentDets(1) = [];
    end
    
    % 步骤7: 删除丢失的轨迹
    toDelete = false(1, length(tracks));
    
    for i = 1:length(tracks)
        if tracks(i).consecutiveInvisibleCount > maxInvisibleCount || ...
           (tracks(i).age > 10 && tracks(i).totalVisibleCount < minVisibleCount)
            toDelete(i) = true;
            
            % 清理状态历史
            if length(stateHistories) >= i
                stateHistories{i} = [];
                dirHistories{i} = [];
            end
        end
    end
    tracks(toDelete) = [];
    stateHistories(toDelete) = [];
    dirHistories(toDelete) = [];
    
    % 返回当前轨迹点
    current_points = [];
    for i = 1:length(tracks)
        current_points(i,:)  = [tracks(i).id tracks(i).x(1:2)'];
    end
end