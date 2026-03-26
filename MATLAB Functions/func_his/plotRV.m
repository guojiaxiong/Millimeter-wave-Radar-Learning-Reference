function RVF = plotRV(data, axis_info)
% data: [ChirpNum x SampleNum]

velocity_axis = axis_info.velocity;
range_axis = axis_info.range;

% 检查尺寸
[ChirpNum, SampleNum] = size(data);
if length(range_axis) ~= SampleNum || length(velocity_axis) ~= ChirpNum
    error('error dimensions.');
end

% 转置数据用于 imagesc 显示 (Y 方向是 V)
RVF = figure;
mesh(velocity_axis, range_axis, abs(data.'));
axis xy;  % 将 Y 轴设为从下到上增长（range方向）
xlabel('Velocity(m/s)');
ylabel('Range (m)');
title('Range-Velocity');
colorbar;
ylim([0 8]);
end