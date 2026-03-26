function VTF = plotVT(data, axis_info)
% data: [FrameNum x SampleNum]

time_axis = axis_info.time;
velocity_axis = axis_info.velocity;

% 检查尺寸
[FrameNum, ChirpNum] = size(data);
if length(velocity_axis) ~= ChirpNum || length(time_axis) ~= FrameNum
    error('error dimensions.');
end

% 转置数据用于 imagesc 显示 (Y 方向是 range)
VTF = figure;
imagesc(time_axis, velocity_axis, abs(data.'));
axis xy;  % 将 Y 轴设为从下到上增长（range方向）
xlabel('Time(s)');
ylabel('velocity (m)');
title('Velocity-Time');
colorbar;
ylim([-5 5]);
end