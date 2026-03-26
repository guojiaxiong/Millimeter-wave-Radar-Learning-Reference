function [hPoint, axTrack] = initTrackFigure(p)
% 初始化图
%% 初始化画布
figTrack = figure('Name', '目标轨迹实时显示', 'WindowState', 'maximized', 'Position', [100, 100, 1400, 800]);
axTrack = axes(figTrack);
axis(axTrack, 'equal');
grid(axTrack, 'on');
hold(axTrack, 'on');
xlabel(axTrack, 'X (m)');
ylabel(axTrack, 'Y (m)');
xlim(axTrack, [p.x(1)-1, p.x(2)+1]); ylim(axTrack, [p.y(1)-1, p.y(2)+1]);
% xlim(axTrack, p.x); ylim(axTrack, p.y);

%% 画点句柄
hPoint = plot(nan, nan, 'ro', 'MarkerSize', 8, 'LineWidth', 2);

%% 添加雷达标记（三角形 + 文字）
plot(axTrack, 0, 0, '^', 'MarkerSize', 15, ...
    'MarkerEdgeColor', 'b', 'MarkerFaceColor', 'b');
text(axTrack, 0.2, 0.2, '雷达', 'FontSize', 15, 'Color', 'b', 'FontWeight', 'bold');

%% 添加表头
text(axTrack, 1, 0.75, 'ID    状态     呼吸率     心率', ...
    'FontName', 'Microsoft YaHei', 'FontSize', 20, ...
    'FontWeight', 'bold', 'Color', 'k', ...
    'Units', 'normalized');

%% 绘制背景场景矩形和标签
switch p.testscene
    case 0  % default
        title(axTrack, '毫米波雷达跟踪定位系统', 'FontSize', 20);
        rectangle(axTrack, 'Position', [p.x(1), p.y(1), diff(p.x), diff(p.y)], ...
            'EdgeColor', 'b', 'LineStyle', '--', 'LineWidth', 1.5);
        text(axTrack, p.x(1), p.y(1) - 0.15, '场景范围', 'FontSize', 15, 'Color', 'b', 'FontWeight', 'bold');
    case 1  % Rooftop
        title(axTrack, '毫米波雷达跟踪定位系统（天台场景）', 'FontSize', 20);
        rectangle(axTrack, 'Position', [p.x(1), p.y(1), diff(p.x), diff(p.y)], ...
            'EdgeColor', 'b', 'LineStyle', '--', 'LineWidth', 1.5);
        text(axTrack, p.x(1), p.y(1) - 0.15, '场景范围', 'FontSize', 15, 'Color', 'b', 'FontWeight', 'bold');
    case 2  % Corridor
        title(axTrack, '毫米波雷达跟踪定位系统（走廊场景）', 'FontSize', 20);
        rectangle(axTrack, 'Position', [p.x(1), p.y(1), diff(p.x), diff(p.y)], ...
            'EdgeColor', 'b', 'LineStyle', '--', 'LineWidth', 1.5);
        text(axTrack, p.x(1), p.y(1) - 0.15, '场景范围', 'FontSize', 15, 'Color', 'b', 'FontWeight', 'bold');
    case 3  % Room
        title(axTrack, '毫米波雷达跟踪定位系统（会议室场景）', 'FontSize', 20);
        rectangle(axTrack, 'Position', [p.x(1), p.y(1), diff(p.x), diff(p.y)], ...
            'EdgeColor', 'b', 'LineStyle', '--', 'LineWidth', 1.5);
        text(axTrack, p.x(1), p.y(1) - 0.15, '场景范围', 'FontSize', 15, 'Color', 'b', 'FontWeight', 'bold');
        rectangle(axTrack, 'Position', [-3.62, -1.45, 0.5, 0.3], ...
            'EdgeColor', 'r', 'FaceColor', 'none', 'LineWidth', 1.2, ...
            'LineStyle', '-');
        text(axTrack, -3.62 + 0.05, -1.45 + 0.5, '空调', ...
            'FontSize', 10, 'Color', 'r', 'FontWeight', 'bold');
end

end