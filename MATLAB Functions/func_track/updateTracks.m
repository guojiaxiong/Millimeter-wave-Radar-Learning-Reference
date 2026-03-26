function [activeTrackIDs, personNum,fullHistoryMap,colorIndex] = updateTracks( ...
    targets, frameIdx,p, personNum, colorIndex,...
    maxdets, mindets,draw)
    persistent colorOrder  
    
    historyMap = p.historyMap;
    % 轨迹完整历史容器（存储所有轨迹点）
    fullHistoryMap = p.fullHistoryMap;
    % 轨迹最后更新时间
    lastUpdateMap = p.lastUpdateMap;
    % 图形句柄
    lineHandles = p.lineHandles;
    pointHandles = p.pointHandles;
    % 轨迹颜色映射
    colorMap = p.colorMap;


    colorOrder = get(gca, 'ColorOrder');
    % --- 1. 轨迹更新 ---
    activeTrackIDs = [];
    for j = 1:size(targets, 1)
        trackID = targets(j, 1);
        position = targets(j, 2:3);
        activeTrackIDs(end+1) = trackID;
        
        % 更新轨迹历史
        if isKey(historyMap, trackID)
            % 追加新位置并限制长度
            newHistory = [historyMap(trackID); position];
            fullHistoryMap(trackID) = [fullHistoryMap(trackID); position];
            if size(newHistory, 1) > maxdets
                newHistory = newHistory(end-maxdets+1:end, :);
            end
            historyMap(trackID) = newHistory;
        else
            % 创建新轨迹
            historyMap(trackID) = position;
            fullHistoryMap(trackID) = position;
            
            % 分配颜色
            color = colorOrder(colorIndex, :);
            colorMap(trackID) = color;
            
            % 更新颜色索引
            colorIndex = mod(colorIndex, size(colorOrder, 1)) + 1;
            
            % 创建图形对象
            lineHandles(trackID) = plot(NaN, NaN, 'Color', color, 'LineWidth', 1.5);
            pointHandles(trackID) = plot(NaN, NaN, 'o', 'Color', color, ...
                'MarkerFaceColor', color, 'MarkerSize', 4);
        end
        
        % 更新最后出现时间
        lastUpdateMap(trackID) = frameIdx;
    end
    
    % 更新人数统计
    personNum = [personNum; frameIdx, length(activeTrackIDs)];
    
    % --- 2. 图形更新 ---
    allTrackIDs = keys(historyMap);
    if draw
        for k = 1:length(allTrackIDs)
            trackID = allTrackIDs{k};
            path = historyMap(trackID);
            
            % 更新轨迹线
            set(lineHandles(trackID), 'XData', path(:,1), 'YData', path(:,2));
            
            if ismember(trackID, activeTrackIDs)
                % 活跃轨迹：显示当前位置
                set(pointHandles(trackID), ...
                    'XData', path(end,1), ...
                    'YData', path(end,2), ...
                    'Visible', 'on');
                % 恢复原始颜色
                set(lineHandles(trackID), 'Color', colorMap(trackID));
            else
                % 非活跃轨迹：隐藏当前位置
                set(pointHandles(trackID), 'Visible', 'off');
            end
        end
    end
    % --- 3. 轨迹清理 ---
    expiredTracks = [];
    allTrackIDs = keys(lastUpdateMap);
    for k = 1:length(allTrackIDs)
        trackID = allTrackIDs{k};
        lastSeen = lastUpdateMap(trackID);
        
        % 检查是否过期
        if (frameIdx - lastSeen) >= mindets
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
        if isKey(fullHistoryMap, trackID)
            remove(fullHistoryMap, trackID);
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