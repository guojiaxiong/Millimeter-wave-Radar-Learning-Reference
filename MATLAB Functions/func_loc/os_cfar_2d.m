function [detections, thresholdMap] = os_cfar_2d(data2d, Tr, Tc, Gr, Gc, Pfa)
% OS-CFAR (Ordered Statistic CFAR) 2D 实现（选择训练单元排序后的第 k 个作为噪声估计）
% 说明：此实现采用经验选择 k = ceil(0.75 * Ntrain)。如果你有严格 Pfa -> k 的映射，
% 可替换此处的 k 或通过仿真标定 alpha。
[Mr, Mc] = size(data2d);
detections = zeros(Mr, Mc);
thresholdMap = zeros(Mr, Mc);

% 训练单元数
Ntrain = (2*Tr+1)*(2*Tc+1) - (2*Gr+1)*(2*Gc+1);
if Ntrain <= 0
    error('训练单元数量 <= 0，请增大 Tr 或 Tc');
end

% 选择序号 k（经验值，可改）
k_frac = 0.9;
k = max(1, min(Ntrain, ceil(k_frac * Ntrain)));

% alpha 近似（这里使用 CA 的 alpha 作为标度的近似）
alpha_ca = Ntrain * (Pfa^(-1/Ntrain) - 1);
% OS 由于使用的是序统计量，需要一个校正因子；用经验缩放：
alpha_os = alpha_ca; % 初始设为相同，建议用仿真校准 Pfa

for r = 1:Mr
    for c = 1:Mc
        r1 = max(1, r - (Tr + Gr)); r2 = min(Mr, r + (Tr + Gr));
        c1 = max(1, c - (Tc + Gc)); c2 = min(Mc, c + (Tc + Gc));
        region = data2d(r1:r2, c1:c2);
        % 清除 guard + CUT
        gr1 = max(1, r - Gr); gr2 = min(Mr, r + Gr);
        gc1 = max(1, c - Gc); gc2 = min(Mc, c + Gc);
        region((gr1 - r1 + 1):(gr2 - r1 + 1), (gc1 - c1 + 1):(gc2 - c1 + 1)) = 0;
        
        % 取非零训练单元向量
        train_cells = region(region~=0);
        N_actual = numel(train_cells);
        if N_actual < k || N_actual == 0
            thresholdMap(r,c) = Inf;
            continue;
        end
        % 排序并取第 k 小（有时用 k 小作为噪声估计）
        sorted_vals = sort(train_cells(:), 'ascend');
        noise_k = sorted_vals(min(k, length(sorted_vals)));
        % 阈值
        threshold = alpha_os * noise_k;
        thresholdMap(r,c) = threshold;
        if data2d(r,c) > threshold
            detections(r,c) = 1;
        end
    end
end
end
