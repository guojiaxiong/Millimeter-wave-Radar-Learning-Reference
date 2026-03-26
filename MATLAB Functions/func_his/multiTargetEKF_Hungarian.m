function tracks = multiTargetEKF_Hungarian(observations, cfarframeIdx, dt)
    % 参数设置
    hB = 0.5; wB = 0.5;           % RD box大小 (可调)
    Q = 0.01 * eye(4);            % 过程噪声
    R = 0.5 * eye(2);             % 测量噪声

    F = [1 0 dt 0; 0 1 0 dt;      % 状态转移矩阵
         0 0 1 0; 0 0 0 1];
    H = [1 0 0 0; 0 1 0 0];       % 观测矩阵

    % 初始化
    maxFrame = max(cfarframeIdx);
    tracks = {};
    nextId = 1;
    maxMissed = 3;  % 最大丢失帧数

    % 每帧处理
    for t = 1:maxFrame
        idx = find(cfarframeIdx == t);
        meas = observations(idx, :);   % 当前帧观测
        numMeas = size(meas, 1);

        % 预测现有轨迹
        for i = 1:length(tracks)
            tracks{i}.x = F * tracks{i}.x;
            tracks{i}.P = F * tracks{i}.P * F' + Q;
        end

        % 构造 cost 矩阵
        K = length(tracks);
        J = zeros(K, numMeas);
        for i = 1:K
            xi = tracks{i}.x(1:2);  % 当前轨迹位置
            Bi = [xi(1)-wB/2, xi(2)-hB/2, wB, hB];
            for j = 1:numMeas
                zj = meas(j, 1:2);  % 当前观测位置
                Bj = [zj(1)-wB/2, zj(2)-hB/2, wB, hB];
                J(i,j) = -computeIOU(Bi, Bj);  % 越小越好
            end
        end

        % 匈牙利匹配
        if ~isempty(J)
            assignment = munkres(J);
        else
            assignment = [];
        end

        % 更新匹配的轨迹
        assigned = false(1, numMeas);
        matchedTracks = false(1, K);

        for i = 1:K
            j = assignment(i);
            if j > 0 && J(i,j) < 0  % IOU有效
                z = meas(j,1:2)';
                y = z - H * tracks{i}.x;
                S = H * tracks{i}.P * H' + R;
                Kf = tracks{i}.P * H' / S;
                tracks{i}.x = tracks{i}.x + Kf * y;
                tracks{i}.P = (eye(4) - Kf * H) * tracks{i}.P;
                tracks{i}.history = [tracks{i}.history; tracks{i}.x'];
                tracks{i}.age = t;
                tracks{i}.missedCount = 0;
                assigned(j) = true;
                matchedTracks(i) = true;
            end
        end

        % 未匹配轨迹计数+1
        for i = 1:K
            if ~matchedTracks(i)
                if isfield(tracks{i}, 'missedCount')
                    tracks{i}.missedCount = tracks{i}.missedCount + 1;
                else
                    tracks{i}.missedCount = 1;
                end
            end
        end

        % 初始化新轨迹
        for j = 1:numMeas
            if ~assigned(j)
                x_init = meas(j,:)';
                P_init = eye(4);
                tracks{end+1} = struct('id', nextId, ...
                                       'x', x_init, ...
                                       'P', P_init, ...
                                       'history', x_init', ...
                                       'age', t, ...
                                       'missedCount', 0);
                nextId = nextId + 1;
            end
        end

        % 删除丢失过多的轨迹
        tracks = tracks(cellfun(@(trk) trk.missedCount <= maxMissed, tracks));
    end
end
