% 主脚本 demo.m
file = '单人角反.dat';          % 您的 .dat 雷达原始数据
chirpsPerFrame = 64;           % 根据实际情况修改
fig = figure('Name', '雷达数据可视化', 'Position', [100, 100, 1000, 600]);

rdr = RadarFrameReader(file,chirpsPerFrame);

frameIdx = 0;
while true
    [rx0Data,rx1Data,chirpIds,hasMore] = rdr.readFrame();
    if isempty(rx0);  break; end
    frameIdx = frameIdx + 1;
    fprintf("已读取第 %d 帧\n",frameIdx);
    
    % 这里可以对 rx0 / rx1 做 FFT、成像等后续处理
    % ----------------------------------------------------------
    visualizeRadarFrame(rx0Data, rx1Data, chirpIds, frameIdx, fig);
    if ~hasMore, break; end
end
rdr.close();




function visualizeRadarFrame(rx0Data, rx1Data, chirpCounts, frameIndex, fig)
% 可视化雷达帧数据 - 只使用两个子图
%
% 输入:
%   rx0Data - RX0通道的所有chirp数据
%   rx1Data - RX1通道的所有chirp数据
%   chirpCounts - chirp序号数组
%   frameIndex - 当前帧索引
%   fig - 图形句柄

% 找到第一个和最后一个非空的chirp索引
firstValidIdx = find(~cellfun(@isempty, rx0Data), 1, 'first');
if isempty(firstValidIdx)
    firstValidIdx = find(~cellfun(@isempty, rx1Data), 1, 'first');
end

lastValidIdx = find(~cellfun(@isempty, rx0Data), 1, 'last');
if isempty(lastValidIdx)
    lastValidIdx = find(~cellfun(@isempty, rx1Data), 1, 'last');
end

% 如果没有找到有效数据，给出提示并退出
if isempty(firstValidIdx) || isempty(lastValidIdx)
    figure(fig);
    clf;
    text(0.5, 0.5, '未找到有效的chirp数据', 'HorizontalAlignment', 'center', 'FontSize', 16);
    return;
end

% 清除当前图形并显示新数据
figure(fig);
clf;

% 创建2个子图的布局
subplot(2,1,1);
hold on;
% RX0通道 - 第一个和最后一个chirp比较
if ~isempty(rx0Data{firstValidIdx}) && ~isempty(rx0Data{lastValidIdx})
    plot(abs(rx0Data{firstValidIdx}), 'b-', 'LineWidth', 1.5);
    plot(abs(rx0Data{lastValidIdx}), 'r-', 'LineWidth', 1.5);
    xlabel('样本点');
    ylabel('幅度');
    legend(sprintf('Chirp %d', chirpCounts(firstValidIdx)), ...
           sprintf('Chirp %d', chirpCounts(lastValidIdx)));
    grid on;
    title('RX0通道数据');
else
    text(0.5, 0.5, 'RX0数据不可用', 'HorizontalAlignment', 'center');
    axis off;
end

subplot(2,1,2);
hold on;
% RX1通道 - 第一个和最后一个chirp比较
if ~isempty(rx1Data{firstValidIdx}) && ~isempty(rx1Data{lastValidIdx})
    plot(abs(rx1Data{firstValidIdx}), 'b-', 'LineWidth', 1.5);
    plot(abs(rx1Data{lastValidIdx}), 'r-', 'LineWidth', 1.5);
    xlabel('样本点');
    ylabel('幅度');
    legend(sprintf('Chirp %d', chirpCounts(firstValidIdx)), ...
           sprintf('Chirp %d', chirpCounts(lastValidIdx)));
    grid on;
    title('RX1通道数据');
else
    text(0.5, 0.5, 'RX1数据不可用', 'HorizontalAlignment', 'center');
    axis off;
end

% 设置总标题
sgtitle(sprintf('雷达帧 #%d 数据分析', frameIndex), 'FontSize', 16);

% 打印统计信息
fprintf('帧 #%d 统计信息:\n', frameIndex);
fprintf('总chirp数: %d\n', length(chirpCounts));
fprintf('有效chirp数 RX0: %d\n', sum(~cellfun(@isempty, rx0Data)));
fprintf('有效chirp数 RX1: %d\n', sum(~cellfun(@isempty, rx1Data)));
fprintf('帧起始chirp序号: %d\n', chirpCounts(firstValidIdx));
fprintf('帧结束chirp序号: %d\n', chirpCounts(lastValidIdx));
end
