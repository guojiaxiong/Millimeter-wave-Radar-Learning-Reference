function hTextList = drawPersonStatusTable(ax, activePersonList, hTextList)
% 在指定坐标轴上绘制人员状态信息文本表格
%
% 输入参数：
%   ax               - 图像坐标轴句柄
%   activePersonList - 活跃人员结构体数组
%   hTextList        - 上一帧的文字句柄数组（用于删除旧内容）
%
% 输出参数：
%   hTextList        - 当前帧的所有文字句柄（供下一帧删除）

    if exist('hTextList', 'var') && ~isempty(hTextList)
        delete(hTextList);
    end
    hTextList = [];

    stateStr = ["静止", "行走", "跑步"];
    n = length(activePersonList);

    % 绘图起始位置
    x0 = 1; y0 = 0.75; dy = 0.04;

    for i = 1:n
        p = activePersonList(i);
        y = y0 - i * dy;

        % 转换心率/呼吸率为字符串
        if p.breathRate == 0
            breathStr = "/";
            heartStr  = "/";
        else
            breathStr = num2str(p.breathRate);
            heartStr  = num2str(p.heartRate);
        end

        % 拼接行字符串
        lineStr = sprintf(" %-4d %-6s    %-6s     %-6s", ...
            p.ID, stateStr(p.S), breathStr, heartStr);

        h = text(ax, x0, y, lineStr, ...
            'FontName', 'Microsoft YaHei', 'FontSize', 20, ...
            'Color', p.Color, 'Units', 'normalized');
        hTextList = [hTextList; h];
    end

    % 总人数行
    y_total = y0 - (n + 1) * dy;
    h = text(ax, x0, y_total, sprintf('总人数：%d', n), ...
        'FontName', 'Microsoft YaHei', 'FontSize', 20, ...
        'FontWeight', 'bold', 'Color', 'k', ...
        'Units', 'normalized');
    hTextList = [hTextList; h];
end
