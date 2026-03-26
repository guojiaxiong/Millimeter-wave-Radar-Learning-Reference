function observations = PositionModel(cfarIdx, axis_info, DoAfiltered)
% 提取目标观测信息并绘图
% 输入:
%   cfarIdx:      [FrameNum × 2] 矩阵，列1为Doppler索引，列2为Range索引
%   axis_info:    结构体，包含 axis_info.range, axis_info.velocity, axis_info.time
%   DoAfiltered:  [FrameNum × 1] 角度估计（单位：度）
% 输出:
%   observations: [FrameNum × 4] 矩阵，每行对应 [x, y, vx, vy]

    FrameNum = size(cfarIdx, 1);

    % 提取距离
    range = zeros(FrameNum, 1);
    for f = 1:FrameNum
        range(f) = axis_info.range(cfarIdx(f, 3));
    end

    % 提取径向速度
    velocity = zeros(FrameNum, 1);
    for f = 1:FrameNum
        velocity(f) = axis_info.velocity(cfarIdx(f, 2));
    end

    % 角度转换为弧度
    theta = deg2rad(DoAfiltered(:)) + pi/2;
    
    % 位置估计
    y = range .* sin(theta);
    x = range .* cos(theta);

    % 速度估计
    velocity = velocity ./ tan(theta);
    vy = velocity .* sin(theta);
    vx = velocity .* cos(theta);

    % 合成观测数据
    observations = [cfarIdx(:, 1), x, y, vx, vy, range, theta];
end
