function [peakRows, peakCols, peakVals] = findpeaks2d(data, varargin)
% FINPEAKS2D 基于Matlab findpeaks的二维寻峰算法
% 输入：
%   data        - 二维数值矩阵（待寻峰数据）
%   varargin    - 可选参数（键值对）：
%                 'MinPeakHeight' - 最小峰高（默认：-Inf）
%                 'MinPeakDistance' - 峰之间的最小欧氏距离（默认：0）
%                 'Neighborhood' - 邻域类型：'8'（默认）或 '4'
% 输出：
%   peakRows    - 峰值的行坐标（1-based）
%   peakCols    - 峰值的列坐标（1-based）
%   peakVals    - 峰值对应的幅值

    % 1. 默认参数初始化
    params = struct(...
        'MinPeakHeight', -Inf, ...
        'MinPeakDistance', 4, ...
        'Neighborhood', '8');
    
    % 解析输入参数（覆盖默认值）
    for i = 1:2:length(varargin)
        if isfield(params, varargin{i})
            params.(varargin{i}) = varargin{i+1};
        else
            warning('未知参数：%s', varargin{i});
        end
    end

    % 2. 输入检查
    if ndims(data) ~= 2
        error('输入必须是二维矩阵！');
    end
    [rows, cols] = size(data);
    if rows < 3 || cols < 3
        error('矩阵尺寸需至少3x3（边界无完整邻域）！');
    end

    % 3. 定义邻域偏移量（行偏移, 列偏移）
    if strcmp(params.Neighborhood, '4')
        % 4邻域：上下左右
        offsets = [[-1,0]; [1,0]; [0,-1]; [0,1]];
    else
        % 8邻域：上下左右+四个对角线（默认）
        offsets = [[-1,-1]; [-1,0]; [-1,1]; ...
                   [0,-1];          [0,1]; ...
                   [1,-1];  [1,0]; [1,1]];
    end

    % 4. 遍历矩阵，筛选候选峰值（排除边界行/列）
    candidateRows = [];
    candidateCols = [];
    candidateVals = [];
    for i = 2:rows-1
        for j = 2:cols-1
            currentVal = data(i,j);
            isPeak = true;
            
            % 比较当前点与所有邻域点
            for k = 1:size(offsets,1)
                ni = i + offsets(k,1);
                nj = j + offsets(k,2);
                if currentVal <= data(ni,nj)
                    isPeak = false;
                    break; % 只要有一个邻域点更大，就不是峰值
                end
            end
            
            % 满足邻域峰值条件，加入候选
            if isPeak
                candidateRows = [candidateRows, i];
                candidateCols = [candidateCols, j];
                candidateVals = [candidateVals, currentVal];
            end
        end
    end

    % 5. 筛选：最小峰高
    heightMask = candidateVals >= params.MinPeakHeight;
    candidateRows = candidateRows(heightMask);
    candidateCols = candidateCols(heightMask);
    candidateVals = candidateVals(heightMask);

    % 6. 筛选：最小峰间距（按幅值降序，保留距离足够的峰）
    if ~isempty(candidateVals) && params.MinPeakDistance > 0
        % 按幅值降序排序（优先保留高幅值峰）
        [sortedVals, sortIdx] = sort(candidateVals, 'descend');
        sortedRows = candidateRows(sortIdx);
        sortedCols = candidateCols(sortIdx);
        
        % 初始化保留的峰索引
        keepIdx = true(size(sortedVals));
        for i = 1:length(sortedVals)
            if keepIdx(i)
                % 计算当前峰与后续所有峰的欧氏距离
                dx = sortedRows(i) - sortedRows(i+1:end);
                dy = sortedCols(i) - sortedCols(i+1:end);
                distances = sqrt(dx.^2 + dy.^2);
                % 距离小于阈值的峰标记为丢弃
                mask = distances < params.MinPeakDistance;
                keepIdx(i+1:end) = keepIdx(i+1:end) & ~mask;
            end
        end
        
        % 应用间距筛选
        candidateRows = sortedRows(keepIdx);
        candidateCols = sortedCols(keepIdx);
        candidateVals = sortedVals(keepIdx);
    end

    % 7. 输出结果
    peakRows = candidateRows;
    peakCols = candidateCols;
    peakVals = candidateVals;
end