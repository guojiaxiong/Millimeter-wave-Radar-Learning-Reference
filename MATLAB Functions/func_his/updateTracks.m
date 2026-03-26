function [activetagets, colorIndex] = updateTracks( ...
    targets, frameIdx, p, colorIndex, draw)
    persistent colorOrder  
    
    % 从p结构体获取所有映射
    historyMap = p.historyMap;
    fullHistoryMap = p.fullHistoryMap;
    lastUpdateMap = p.lastUpdateMap;
    lineHandles = p.lineHandles;
    pointHandles = p.pointHandles;
    colorMap = p.colorMap;
    motionStateMap = p.motionStateMap;  
    maxdets = p.maxdets;
    mindets = p.mindets;
    colorOrder = get(gca, 'ColorOrder');
    activetagets = [];
    % --- 1. 轨迹更新 ---
    activeTrackIDs = [];
    for j = 1:size(targets, 1)
        trackID = targets(j, 1);
        position = targets(j, 2:3);
        motionState = targets(j, 4); %  1=静止 2=行走 3=跑步
        activeTrackIDs(end+1) = trackID;
        
        % 更新轨迹历史和运动状态
        if isKey(historyMap, trackID)
            newHistory = [historyMap(trackID); position];
            fullHistory = [fullHistoryMap(trackID); position];
            if size(newHistory, 1) > maxdets
                newHistory = newHistory(end-maxdets+1:end, :);
            end
            historyMap(trackID) = newHistory;
            fullHistoryMap(trackID) = fullHistory;
        else
            historyMap(trackID) = position;
            fullHistoryMap(trackID) = position;
            
            color = colorOrder(colorIndex, :);
            colorMap(trackID) = color;
            colorIndex = mod(colorIndex, size(colorOrder, 1)) + 1;
            
            % 根据运动状态创建点标记
            state = ["静止" "行走" "跑步"];
            stateStr = state(motionState);
            lineHandles(trackID) = plot(NaN, NaN, 'Color', color, 'LineWidth', 1.5, 'HandleVisibility', 'off');
            pointHandles(trackID) = plot(NaN, NaN, 'o', 'Color', color, ...
                'MarkerFaceColor', color, 'MarkerSize', 6, 'DisplayName', stateStr);
        end
        % 更新运动状态和最后检测时间
        motionStateMap(trackID) = motionState;
        lastUpdateMap(trackID) = frameIdx;
        
        % 更新点标记显示状态
        state = ["静止" "行走" "跑步"];%  1=静止 2=行走 3=跑步
        stateStr = state(motionState);
        set(pointHandles(trackID), 'DisplayName', stateStr);
        
    end
    %legend();
    % --- 2. 静止轨迹补充点处理 ---
    allTrackIDs = keys(historyMap);
    supplementedTracks = [];
    for k = 1:length(allTrackIDs)
        trackID = allTrackIDs{k};
        % 仅处理未更新的静止轨迹
        if ~ismember(trackID, activeTrackIDs) && ...
           isKey(motionStateMap, trackID) && ...
           motionStateMap(trackID) == 1 && ...
           size(fullHistoryMap(trackID), 1) > 30
            
            lastSeen = lastUpdateMap(trackID);
            if (frameIdx - lastSeen) < 40  % 在容忍期内
                % 复制最后已知位置作为新点
                lastPos = historyMap(trackID); % 获取整个轨迹
                lastPos = lastPos(end, :);     % 取最后一行
                
                % 更新轨迹历史
                newHistory = [historyMap(trackID); lastPos];
                if size(newHistory, 1) > maxdets
                    newHistory = newHistory(end-maxdets+1:end, :);
                end
                historyMap(trackID) = newHistory;
                
                % 更新完整历史
                fullHistoryMap(trackID) = [fullHistoryMap(trackID); lastPos];
                
                % 标记为补充轨迹
                supplementedTracks(end+1) = trackID;
            end
        end
    end
    % 将补充轨迹加入活跃列表
    activeTrackIDs = [activeTrackIDs, supplementedTracks];
    
    % 更新人数统计
    personNum = length(activeTrackIDs);
    % --- 3. 图形更新 ---
    if draw
        for k = 1:length(allTrackIDs)
            trackID = allTrackIDs{k};
            path = historyMap(trackID);

            set(lineHandles(trackID), 'XData', path(:,1), 'YData', path(:,2));
            
            if ismember(trackID, activeTrackIDs)
                set(pointHandles(trackID), ...
                    'XData', path(end,1), ...
                    'YData', path(end,2), ...
                    'Visible', 'on');
                set(lineHandles(trackID), 'Color', colorMap(trackID));
                activetagets = [activetagets; trackID path(end,:) motionStateMap(trackID) colorMap(trackID) personNum];
            else
                set(pointHandles(trackID), 'Visible', 'off');
            end
        end
    end
    
    % --- 4. 轨迹清理 ---
    expiredTracks = [];
    allTrackIDs = keys(lastUpdateMap);
    for k = 1:length(allTrackIDs)
        trackID = allTrackIDs{k};
        lastSeen = lastUpdateMap(trackID);
        framesSinceUpdate = frameIdx - lastSeen;
        
        % 获取轨迹状态和历史长度
        if isKey(motionStateMap, trackID)
            motionState = motionStateMap(trackID);
        else
            motionState = 0; % 默认运动状态
        end
        
        if isKey(fullHistoryMap, trackID)
            histLength = size(fullHistoryMap(trackID), 1);
        else
            histLength = 0;
        end
        
        % 根据轨迹类型确定过期条件
        if motionState == 1 && histLength > 30
            maxFrames = 40; % 静止轨迹容忍帧数
        else
            maxFrames = mindets; % 普通轨迹容忍帧数
        end
        
        if framesSinceUpdate >= maxFrames
            % 删除图形对象
            if isKey(lineHandles, trackID)
                delete(lineHandles(trackID));
            end
            if isKey(pointHandles, trackID)
                delete(pointHandles(trackID));
            end
            expiredTracks(end+1) = trackID;
        end
    end
    
    % 清理过期轨迹资源
    for k = 1:length(expiredTracks)
        trackID = expiredTracks(k);
        if isKey(historyMap, trackID), remove(historyMap, trackID); end
        if isKey(fullHistoryMap, trackID), remove(fullHistoryMap, trackID); end
        if isKey(lastUpdateMap, trackID), remove(lastUpdateMap, trackID); end
        if isKey(colorMap, trackID), remove(colorMap, trackID); end
        if isKey(lineHandles, trackID), remove(lineHandles, trackID); end
        if isKey(pointHandles, trackID), remove(pointHandles, trackID); end
        if isKey(motionStateMap, trackID), remove(motionStateMap, trackID); end % 新增
    end
    
    % --- 5. 更新p结构体 ---
    p.historyMap = historyMap;
    p.fullHistoryMap = fullHistoryMap;
    p.lastUpdateMap = lastUpdateMap;
    p.lineHandles = lineHandles;
    p.pointHandles = pointHandles;
    p.colorMap = colorMap;
    p.motionStateMap = motionStateMap; % 新增
end