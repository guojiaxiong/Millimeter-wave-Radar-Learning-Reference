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
figure;
subplot(211);
imagesc(time_axis, range_axis, abs(data.'));
axis xy;  % 将 Y 轴设为从下到上增长（range方向）
xlabel('Time(s)');
ylabel('Range (m)');
title('Range-Time');
colorbar;
subplot(212);
mesh(time_axis, range_axis, abs(data.'));
axis xy;  % 将 Y 轴设为从下到上增长（range方向）
xlabel('Time(s)');
ylabel('Range (m)');
title('Range-Time');
colorbar;
end