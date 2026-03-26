function localMaxima = findLocalMaximaInIdx(matrix, idx, Target_number)
% FINDLOCALMAXIMAINIDX 在指定矩阵中查找局部最大值，并返回前N个幅值最大的极值点坐标
% 【核心功能】
%   1. 在矩阵中以 idx×idx 为窗口搜索局部最大值（中心值 > 窗口内所有邻域值）；
%   2. 过滤边界元素（避免窗口越界）；
%   3. 若找到的极值点数量超过 Target_number，仅保留幅值最大的前 Target_number 个。
% 
% 【输入参数】
%   matrix        : 二维矩阵（必填），待搜索局部最大值的原始数据（如雷达角度谱、距离-角度谱）
%   idx           : 标量（必填），局部最大值搜索窗口的尺寸（奇数，如3/5/7，代表idx×idx窗口）
%   Target_number : 标量（必填），需要保留的目标极值点数量（如1/2，代表提取前N个最大极值）
% 
% 【输出参数】
%   localMaxima   : 二维矩阵，每行格式为 [行坐标, 列坐标, 极值点幅值]，行数≤Target_number
%                   - 第1列：极值点在matrix中的行索引
%                   - 第2列：极值点在matrix中的列索引
%                   - 第3列：极值点对应的幅值（用于排序）
% 
% 【算法限制】
%   1. idx 建议使用奇数（如3/5），若输入偶数会自动通过ceil/floor取整为奇数逻辑；
%   2. 搜索范围自动避开矩阵边界（窗口不越界）；
%   3. 仅识别"严格局部最大值"（中心值 > 所有邻域值，不包含等于的情况）。

    % 获取输入矩阵的行列尺寸
    [m, n] = size(matrix);

    % 初始化空矩阵，存储局部最大值的[行坐标, 列坐标, 幅值]
    localMaxima = [];

    % 遍历矩阵（避开边界，确保idx×idx窗口不越界）
    % 起始行/列：ceil(idx/2) → 窗口中心不超出矩阵左/上边界
    % 终止行：m-floor(idx/2) → 窗口中心不超出矩阵下边界
    % 终止列：0.5*n-floor(idx/2) → 仅搜索矩阵前半列（适配雷达距离-角度谱的特殊场景）
    for i = ceil(idx/2):m-floor(idx/2)
        for j = ceil(idx/2):0.5*n-floor(idx/2)
            % 提取当前中心(i,j)对应的idx×idx邻域子矩阵
            subMatrix = matrix(i-floor(idx/2):i+floor(idx/2), j-floor(idx/2):j+floor(idx/2));
            % 获取当前中心位置的幅值
            currentValue = matrix(i, j);
            % 将邻域子矩阵展开为一维数组（便于后续排除中心值）
            neighbors = subMatrix(:);
            % 计算中心值在邻域子矩阵中的索引（用于剔除）
            centerIndex = sub2ind(size(subMatrix), ceil(idx/2), ceil(idx/2));
            neighbors(centerIndex) = []; % 剔除中心值，仅保留邻域值

            % 判断当前值是否为严格局部最大值（中心值 > 所有邻域值）
            if all(currentValue > neighbors)
                localMaxima = [localMaxima; i, j, currentValue]; % 保存极值点信息
            end
        end
    end

    % 若找到的极值点数量超过目标数量，按幅值降序排序并保留前Target_number个
    if size(localMaxima, 1) > Target_number
        localMaxima = sortrows(localMaxima, -3); % 按第3列（幅值）降序排序
        localMaxima = localMaxima(1:Target_number, :); % 截取前Target_number个极值点
    end
end