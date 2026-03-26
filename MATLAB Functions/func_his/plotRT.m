function RTF = plotRT(data, axis_info)
% data: [FrameNum x SampleNum]

time_axis = axis_info.time;
range_axis = axis_info.range;

% 检查尺寸
[FrameNum, SampleNum] = size(data);
if length(range_axis) ~= SampleNum || length(time_axis) ~= FrameNum
    error('error dimensions.');
end

% 转置数据用于 imagesc 显示 (Y 方向是 range)
RTF = figure;
mesh(time_axis, range_axis, abs(data.'));
axis xy;  % 将 Y 轴设为从下到上增长（range方向）
xlabel('Time(s)');
ylabel('Range (m)');
title('Range-Time');
colorbar;
ylim([0 8]);
end
