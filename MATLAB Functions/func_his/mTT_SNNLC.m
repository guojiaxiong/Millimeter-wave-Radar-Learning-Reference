% 基于最近邻与轨迹生命周期管理的多目标跟踪算法
% 输入：observations - 每人观测数据的 cell 数组，每个 cell 为 [FrameNum, 4]（x, y, vx, vy）
%       dt - 时间步长
% 输出：输出图中展示跟踪结果，输出 tracks 保存所有目标轨迹

function tracks = mTT_SNNLC(observations, dt)

PersonNum = length(observations);
FrameNum = size(observations{1}, 1);

% Kalman滤波参数
F = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1];  % 状态转移矩阵
H = [1 0 0 0; 0 1 0 0];                     % 观测矩阵
Q = 0.01 * eye(4);                          % 过程噪声
R = 1.0 * eye(2);                           % 观测噪声

% 跟踪参数
tracks = {};
nextId = 1;
maxMissed = 5;      % 最大未匹配帧数
confirmThreshold = [5, 8];  % [N, M] 判定确认目标（如5/8）

% 所有帧处理
for k = 1:FrameNum
    % 当前帧所有观测 [x, y, vx, vy]
    currentObs = [];
    for p = 1:PersonNum
        currentObs = [currentObs; observations{p}(k, :)];
    end

    % 1. 预测
    for i = 1:length(tracks)
        tracks{i}.x = F * tracks{i}.x;
        tracks{i}.P = F * tracks{i}.P * F' + Q;
    end

    % 2. 数据关联（最近邻）
    assigned = false(1, size(currentObs, 1));
    for i = 1:length(tracks)
        pred = H * tracks{i}.x;
        dists = vecnorm(currentObs(:,1:2)' - pred, 2, 1);
        [minDist, idx] = min(dists);

        if minDist < 10  % 距离门限
            % 更新Kalman
            z = currentObs(idx, 1:2)';
            y = z - H * tracks{i}.x;
            S = H * tracks{i}.P * H' + R;
            K = tracks{i}.P * H' / S;
            tracks{i}.x = tracks{i}.x + K * y;
            tracks{i}.P = (eye(4) - K * H) * tracks{i}.P;
            
            tracks{i}.history = [tracks{i}.history; tracks{i}.x'];
            tracks{i}.matchedCount = tracks{i}.matchedCount + 1;
            tracks{i}.totalCount = tracks{i}.totalCount + 1;
            tracks{i}.missedCount = 0;
            assigned(idx) = true;
        else
            tracks{i}.missedCount = tracks{i}.missedCount + 1;
            tracks{i}.totalCount = tracks{i}.totalCount + 1;
        end
    end

    % 3. 创建新轨迹（未分配观测）
    for i = 1:size(currentObs, 1)
        if ~assigned(i)
            obs = currentObs(i, :);
            x_init = obs';
            P_init = eye(4);
            newTrack = struct('id', nextId, 'x', x_init, 'P', P_init, ...
                              'history', x_init', 'matchedCount', 1, ...
                              'totalCount', 1, 'missedCount', 0);
            tracks{end+1} = newTrack;
            nextId = nextId + 1;
        end
    end

    % 4. 移除未匹配轨迹
    toKeep = true(1, length(tracks));
    for i = 1:length(tracks)
        if tracks{i}.missedCount >= maxMissed
            toKeep(i) = false;
        end
    end
    tracks = tracks(toKeep);
end

% 5. 可视化
figure; hold on;
colors = lines(length(tracks));
for i = 1:length(tracks)
    % 判定是否为有效目标
    if tracks{i}.matchedCount >= confirmThreshold(1) && ...
       tracks{i}.totalCount <= confirmThreshold(2)
        h = tracks{i}.history;
        plot(h(:,1), h(:,2), '-o', 'Color', colors(i,:));
    end
end
xlabel('X [m]'); ylabel('Y [m]');
title('Multi-Target Tracking Result'); grid on;

end
