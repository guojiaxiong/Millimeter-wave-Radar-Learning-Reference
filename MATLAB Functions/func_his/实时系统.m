function main()
    % ======== 用户参数 ========
    port           = "COM5";  % 串口号
    chirpsPerFrame = 64;      % 每帧 chirp 数
    drawEveryN     = 1;       % 每 N 帧更新一次曲线，可减小 UI 压力
    % ==========================
    % 初始化雷达参数
    p = setRadarParameters();
    % 初始化雷达串口读取类
    rdr = read_Raw_serial(port, chirpsPerFrame);


    % 初始化轨迹图像窗口
    figure('Name', '目标轨迹实时显示');
    axTrack = axes();
    axis equal;
    grid on;
    hold on;
    xlabel('X (m)');
    ylabel('Y (m)');
    title('目标轨迹实时显示');
    xlim([-5,5]);
    ylim([-1.5,7]);
    % 在初始化轨迹图像窗口之后添加
    switch p.testscene
        case 1  % Rooftop
            rectangle(axTrack, 'Position', [p.x(1), p.y(1), diff(p.x), diff(p.y)], ...
                      'EdgeColor', [0.2 0.2 0.8], 'LineStyle', '--', 'LineWidth', 1.5);
            text(-5.5, 7.5, 'Rooftop', 'FontSize', 12, 'Color', 'b');
        case 2  % Corridor
            rectangle(axTrack, 'Position', [p.x(1), p.y(1), diff(p.x), diff(p.y)], ...
                      'EdgeColor', [0.8 0.4 0.1], 'LineStyle', '--', 'LineWidth', 1.5);
            text(-3, 4.2, 'Corridor', 'FontSize', 12, 'Color', [0.8 0.4 0.1]);
        case 3  % Room
            rectangle(axTrack, 'Position', [p.x(1), p.y(1) - 1, diff(p.x), diff(p.y) + 1], ...
                    'EdgeColor', [0.1 0.7 0.2], 'LineStyle', '--', 'LineWidth', 1.5);
            text(-3, 4.2, 'Room', 'FontSize', 12, 'Color', [0.1 0.7 0.2]);
    end

    rectangle(axTrack, 'Position', [-3.8, -1.45, 0.5, 0.3], ...
              'EdgeColor', 'c', 'FaceColor', 'none', 'LineWidth', 1.2, ...
              'LineStyle', '-');  % 青色轮廓
    % 添加文字说明
    text(-3.8 + 0.05, -1.45 + 0.5, '空调', ...
         'FontSize', 10, 'Color', 'c', 'FontWeight', 'bold');
    % 添加雷达位置（蓝色三角形）
    plot(axTrack, 0, 0, '^', 'MarkerSize', 10, ...
         'MarkerEdgeColor', 'b', 'MarkerFaceColor', 'b');  % '^' 表示向上的三角形
    text(0.3, 0.2, 'Radar', 'FontSize', 10, 'Color', 'b', 'FontWeight', 'bold');
        

    %设置资源释放阈值
    maxdets = 50; %每条轨迹最多存储的点数
    mindets = 10; %超过10次没有更新，轨迹资源释放
    
    % 轨迹历史容器
    historyMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
    % 轨迹最后更新时间
    lastUpdateMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
    % 图形句柄
    lineHandles = containers.Map('KeyType', 'double', 'ValueType', 'any');
    pointHandles = containers.Map('KeyType', 'double', 'ValueType', 'any');
    % 轨迹颜色映射
    colorMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
    
    % 创建检测点散点图句柄 - 用于显示原始检测点
    detectScatter = scatter(axTrack, [], [], 50, 'o', 'MarkerEdgeColor', 'r', ...
        'LineWidth', 2, 'DisplayName', '原始检测点');
    
    % 设置颜色循环
    colorOrder = get(gca, 'ColorOrder');
    colorIndex = 1;

    frameCnt = 0;
    while true
        tStart = tic;

        % ---- 读一帧 ----
        [rx0Cell, rx1Cell, ~, hasMore] = rdr.readFrame();
        if ~hasMore
            disp("数据读取完毕，退出循环");  break;
        end
        frameCnt = frameCnt + 1;

        %每隔10帧清空一次缓冲区，防止延后
        if mod(frameCnt, 200) == 0
            disp("清空串口缓存");
            rdr.clear_buffer(); 
        end

        % 处理雷达数据并检测目标，返回轨迹和检测点
        [targets, detec] = processRadarAndDetectTargets(rx0Cell, rx1Cell, p, frameCnt);

        % 更新检测点散点图 (detec为原始检测点)
        if ~isempty(detec)
            set(detectScatter, 'XData', detec(:,1), 'YData', detec(:,2));
        else
            set(detectScatter, 'XData', [], 'YData', []);
        end
        % 仅当有目标轨迹时更新轨迹
        if ~isempty(targets)
            % targets是一个N×3的矩阵，其中第一列是ID，后两列是x,y坐标
            % 当前活跃轨迹ID
            activeTrackIDs = [];
            for j = 1:size(targets, 1)
                trackID = targets(j, 1);
                position = targets(j, 2:3);
                activeTrackIDs(end+1) = trackID;
                
                % 更新轨迹历史
                if isKey(historyMap, trackID)
                    % 追加新位置并限制长度
                    newHistory = [historyMap(trackID); position];
                    if size(newHistory, 1) > maxdets
                        newHistory = newHistory(end-maxdets+1:end, :);
                    end
                    historyMap(trackID) = newHistory;
                else
                    % 创建新轨迹
                    historyMap(trackID) = position;
                    % 为新轨迹分配颜色
                    lineHandles(trackID) = plot(axTrack, NaN, NaN, ...
                        'Color', colorOrder(colorIndex, :), ...
                        'LineWidth', 1.5, 'DisplayName', sprintf('轨迹 #%d', trackID));

                    pointHandles(trackID) = plot(axTrack, NaN, NaN, 'o', ...
                        'Color', colorOrder(colorIndex, :), ...
                        'MarkerFaceColor', colorOrder(colorIndex, :), ...
                        'MarkerSize', 4, 'HandleVisibility', 'off');  % 轨迹点不显示在图例中

                    % 更新颜色索引
                    colorIndex = mod(colorIndex, size(colorOrder, 1)) + 1;
                end

               % 更新图形
                path = historyMap(trackID);
                set(lineHandles(trackID), 'XData', path(:,1), 'YData', path(:,2));
                set(pointHandles(trackID), 'XData', path(end,1), 'YData', path(end,2));

                % 更新最后出现时间
                lastUpdateMap(trackID) = frameCnt;  

            end
        end
        % 每drawEveryN帧更新一次图像显示
        if mod(frameCnt, drawEveryN) == 0 || ismember(trackID, activeTrackIDs)
%             title(sprintf('Frame %d - 跟踪目标: %d - 检测点: %d FPS: %.1f', ...
%                 frameCnt, numel(keys(historyMap)), size(detec, 1),1/toc(tStart)));
            title(sprintf(' 跟踪目标: %d - 检测点: %d FPS: %.1f', ...
                 numel(keys(historyMap)), size(detec, 1),1/toc(tStart)));
            drawnow;
        end

        fprintf('Frame %-5d  FPS %.4f \n', frameCnt, 1/toc(tStart));

        % ====== 轨迹清理 ======
        expiredTracks = [];
        allTrackIDs = keys(lastUpdateMap);
        for k = 1:length(allTrackIDs)
            trackID = allTrackIDs{k};
            lastSeen = lastUpdateMap(trackID);
            
            % 检查是否过期
            if (frameCnt - lastSeen) >= mindets
                % 删除图形对象
                delete(lineHandles(trackID));
                delete(pointHandles(trackID));
                % 记录待删除轨迹
                expiredTracks(end+1) = trackID;
            end
        end
        
        % 清理过期轨迹资源
        for k = 1:length(expiredTracks)
            trackID = expiredTracks(k);
            if isKey(historyMap, trackID)
                remove(historyMap, trackID);
            end
            if isKey(lastUpdateMap, trackID)
                remove(lastUpdateMap, trackID);
            end
            if isKey(colorMap, trackID)
                remove(colorMap, trackID);
            end
            if isKey(lineHandles, trackID)
                remove(lineHandles, trackID);
            end
            if isKey(pointHandles, trackID)
                remove(pointHandles, trackID);
            end
        end
    end
    % 关闭串口
    rdr.close();
    disp("程序结束，串口已关闭");
end