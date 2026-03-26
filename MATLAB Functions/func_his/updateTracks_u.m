function [activetagets, colorIndex] = updateTracks_u(targets, frameIdx, p, colorIndex, draw)
    persistent colorOrder  
    
    % 从p结构体获取所有映射
    historyMap = p.historyMap;          % 历史轨迹容器，最多存50个点
    fullHistoryMap = p.fullHistoryMap;  % 全部历史轨迹容器 
    lastUpdateMap = p.lastUpdateMap;    % 轨迹最后更新时间
    lineHandles = p.lineHandles;        % 轨迹线句柄
    pointHandles = p.pointHandles;      % 轨迹最新点句柄
    colorMap = p.colorMap;
    motionStateMap = p.motionStateMap;  
    maxdets = p.maxdets;
    mindets = p.mindets;
    activetagets = [];
    colorOrder = get(gca, 'ColorOrder');
    
    % --- 1. 轨迹更新（新增噪点过滤）---
    activeTrackIDs = [];
    for j = 1:size(targets, 1)
        trackID = targets(j, 1);
        newPosition = targets(j, 2:3);
        motionState = targets(j, 4);
        
        % 噪点过滤：距离>2m时用上一个点代替
        if isKey(historyMap, trackID)
            newp = historyMap(trackID);
            lastPos = newp(end, :);
            distance = norm(newPosition - lastPos);
            if distance > 2  % 超过2米视为噪点
                position = lastPos;
            else
                position = newPosition;
            end
        else
            position = newPosition;  % 新轨迹直接使用
        end
        
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
            if motionState == 1
                stateStr = '静止';
            else
                stateStr = '运动';
            end
            
            lineHandles(trackID) = plot(NaN, NaN, 'Color', color, 'LineWidth', 1.5, 'HandleVisibility', 'off');
            pointHandles(trackID) = plot(NaN, NaN, 'o', 'Color', color, ...
                'MarkerFaceColor', color, 'MarkerSize', 6, 'DisplayName', stateStr);
        end
        
        % 更新运动状态和最后检测时间
        motionStateMap(trackID) = motionState;
        lastUpdateMap(trackID) = frameIdx;
        
        % 更新点标记显示状态
        if motionState == 1
            stateStr = '静止';
        else
            stateStr = '运动';
        end
         set(pointHandles(trackID), 'DisplayName', stateStr);
    end
%     legend();
    
    % --- 2. 静止轨迹补充点处理 ---
    allTrackIDs = keys(historyMap);
    supplementedTracks = [];
    for k = 1:length(allTrackIDs)
        trackID = allTrackIDs{k};
        % 仅处理未更新的静止轨迹
        if ~ismember(trackID, activeTrackIDs) && ...
           isKey(motionStateMap, trackID) && ...
           motionStateMap(trackID) == 1 && ...
           size(fullHistoryMap(trackID), 1) >= 25  % 修改条件为>=25
            
            lastSeen = lastUpdateMap(trackID);
            if (frameIdx - lastSeen) < 40  % 在容忍期内
                % 复制最后已知位置作为新点
                newp = historyMap(trackID);
                lastPos = newp(end, :); % 取最后一个点
                
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
    % --- 4. 轨迹清理（新增短轨迹处理）---
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
            motionState = 0;
        end
        
        histLength = size(fullHistoryMap(trackID), 1);
        
        % 新增：短轨迹特殊处理（<25帧）
        if histLength < 15
            if framesSinceUpdate >= 10  % 短轨迹10帧未更新则删除
                expiredTracks(end+1) = trackID;
            end
            continue;  % 跳过后续检查
        end
        
        % 根据轨迹类型确定过期条件
        if motionState == 1
            maxFrames = 40; % 静止轨迹容忍帧数
        else
            maxFrames = mindets; % 运动轨迹使用标准容忍帧数
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
        if isKey(motionStateMap, trackID), remove(motionStateMap, trackID); end
    end
    
    % --- 5. 更新p结构体 ---
    p.historyMap = historyMap;
    p.fullHistoryMap = fullHistoryMap;
    p.lastUpdateMap = lastUpdateMap;
    p.lineHandles = lineHandles;
    p.pointHandles = pointHandles;
    p.colorMap = colorMap;
    p.motionStateMap = motionStateMap;
end