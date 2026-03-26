function show_track(tracks)
 hold on; grid on;
    axis equal;
    % 绘制真实轨迹
    colors = [
        0 0.45 0.74;   % 科技蓝
        0.85 0.33 0.1;  % 橙红
        0.93 0.69 0.13; % 金黄
        0.49 0.18 0.56; % 紫罗兰
        0.47 0.67 0.19; % 青绿
        0.3 0.75 0.93 ;  % 天蓝
        0.69 0.87 0.9 ;
        0.27 0.51 0.7 ;
        0.47 0.53 0.6  %深灰
    ];
%     
%     % 绘制检测点
%     allDets = vertcat(detections{:});
%     scatter(allDets(:,1), allDets(:,2), '*','MarkerEdgeColor',colors(9,:) ,...
%         'DisplayName', 'Detections');
    
    for t = 1:length(tracks) 
        if ~isempty(tracks(t).history) && tracks(t).totalVisibleCount>2
            plot(tracks(t).history(:,1), tracks(t).history(:,2), ...
                '-', 'LineWidth', 1.5);
        end
    end
    
    hold on; grid on;
    xlim([-5 5]);ylim([0 9]);
    xlabel('X Position');
    ylabel('Y Position');
    title('多目标跟踪结果');
end