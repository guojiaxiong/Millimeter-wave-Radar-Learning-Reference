function [targetList, cfarIdx] = detectTopNTargets(RD_map, N, suppressWin, frameIdx, energyThresh)
% 从 Range-Velocity 图中提取最强 N 个目标点，并生成 cfarIdx
% RD_map: [Velocity x Range] 幅度图（建议用 abs 或 dB）
% N: 要检测的目标数量
% suppressWin: 抑制窗口大小（例如 [5 5] 表示5x5屏蔽）
% frameIdx: 当前帧的索引
% energyThresh: 能量阈值，低于此值的目标将被忽略

[M, Ncol] = size(RD_map);
targetList = [];  % [vIdx, rIdx, amplitude]
cfarIdx = [];     % 存储 [frameIdx, vIdx, rIdx]

RD_work = RD_map;  % 用于屏蔽的副本

for k = 1:N
    [maxVal, linearIdx] = max(RD_work(:));  % 找到最大值及其线性索引
    if maxVal <= 0
        break;  % 无更多目标
    end
    [vIdx, rIdx] = ind2sub(size(RD_map), linearIdx);  % 将线性索引转换为二维索引
    
    % 如果目标能量小于阈值，忽略该目标
    if maxVal < energyThresh
        continue;  % 跳过当前目标
    end
    
    targetList = [targetList; vIdx, rIdx, maxVal];  % 将目标信息加入目标列表

    % 更新 cfarIdx 变量，记录当前帧的 Doppler bin 和 Range bin 索引
    cfarIdx = [cfarIdx; frameIdx, vIdx, rIdx];  % 添加当前帧的目标信息

    % 屏蔽邻域，防止重复检测
    vMin = max(1, vIdx - suppressWin(1));  % 确保屏蔽区域不越界
    vMax = min(M, vIdx + suppressWin(1));
    rMin = max(1, rIdx - suppressWin(2));
    rMax = min(Ncol, rIdx + suppressWin(2));
    
    % 屏蔽该邻域内的区域，防止检测到重复目标
    RD_work(vMin:vMax, rMin:rMax) = 0;  % 将邻域区域置为0
end
end
