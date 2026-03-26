function [ekfinput, Buffer] = mPfilter(observations, jframe, Buffer, axTrack, p)
% 对当前帧的观测数据进行多径滤波、聚类和可视化处理
%
% 输入参数：
%   observations - 当前帧观测数据 [frame, x, y, vx, vy]
%   jframe       - 当前帧号
%   Buffer       - 帧数据缓冲区（用于多径滤波）
%   axTrack      - 轨迹显示的图像坐标轴
%   p            - 参数结构体（用于滤波）
%
% 输出参数：
%   ekfinput     - 当前帧聚类后的观测（用于EKF等跟踪） [x, y, vx, vy]
%   Buffer       - 更新后的缓冲区

    windowsize = 3;

    % 加入缓冲区并维护窗口大小
    observations(:, 1) = jframe;
    Buffer = [Buffer; observations];
    if size(Buffer, 1) > windowsize
        Buffer(Buffer(:, 1) == jframe - windowsize, :) = [];
    end

    % 多径滤波
    observations_filterd = mutlpathfilt(Buffer, p);

    % 当前帧无有效观测
    if isempty(observations_filterd)
        disp('no tag');
        return;
    end

    % 提取当前帧的观测
    observations_filterd(observations_filterd(:, 1) ~= jframe, :) = [];
    if isempty(observations_filterd)
        disp('no tag');
        return;
    end

    % DBSCAN 聚类 + 可视化
    ekfinput = frame_dbscan(observations_filterd, 0.6, 1);
    ekfinput = ekfinput(:, 2:5);

    plot(axTrack, observations_filterd(:, 2), observations_filterd(:, 3), 'g+');
    plot(axTrack, ekfinput(:, 2), ekfinput(:, 3), 'ro');
end
