function tracks = multiTargetTracking(observations, dt)
% 输入:
%   observations: cell array, 每帧观测 [x, y, vx, vy]
%   dt: 时间步长
% 输出:
%   tracks: cell数组，每个目标包含状态估计及轨迹 history

    numFrames = length(observations);
    tracks = {};  % 存储每个目标
    nextId = 1;

    % Kalman参数
    F = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1];
    H = [1 0 0 0; 0 1 0 0];
    Q = 0.01 * eye(4);
    R = 1.0 * eye(2);

    for k = 1:numFrames
        meas = observations(k,:);  % 当前帧观测 [x y vx vy]
        numMeas = size(meas, 1);

        % 预测阶段
        for i = 1:length(tracks)
            track = tracks{i};
            track.x = F * track.x;
            track.P = F * track.P * F' + Q;
            tracks{i} = track;
        end

        % 简单最近邻匹配
        assigned = false(1, numMeas);
        for i = 1:length(tracks)
            track = tracks{i};
            pred = H * track.x;
            dists = vecnorm(meas(:,1:2)' - pred, 2, 1);
            [minDist, idx] = min(dists);
            if minDist < 10
                z = meas(idx, 1:2)';
                y = z - H * track.x;
                S = H * track.P * H' + R;
                K = track.P * H' / S;
                track.x = track.x + K * y;
                track.P = (eye(4) - K * H) * track.P;
                track.history = [track.history; track.x'];
                assigned(idx) = true;
            end
            tracks{i} = track;
        end

        % 初始化未匹配目标
        for i = 1:numMeas
            if ~assigned(i)
                x_init = [meas(i,1); meas(i,2); meas(i,3); meas(i,4)];
                P_init = eye(4);
                tracks{end+1} = struct('id', nextId, ...
                                       'x', x_init, ...
                                       'P', P_init, ...
                                       'history', x_init');
                nextId = nextId + 1;
            end
        end
    end
end
