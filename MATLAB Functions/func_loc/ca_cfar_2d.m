%% =========== 辅助函数：二维 CA-CFAR ===========
function [detections, thresholdMap] = ca_cfar_2d(data2d, Tr, Tc, Gr, Gc, Pfa)
% data2d: 输入功率矩阵 (rows: range, cols: doppler)
[Mr, Mc] = size(data2d);
detections = zeros(Mr, Mc);
thresholdMap = zeros(Mr, Mc);

% 训练单元数（总数）
Ntrain = (2*Tr+1)*(2*Tc+1) - (2*Gr+1)*(2*Gc+1);
if Ntrain <= 0
    error('训练单元数量 <= 0，请增大 Tr 或 Tc');
end
% 近似 alpha（比例因子）
alpha = Ntrain * (Pfa^(-1/Ntrain) - 1);

% 遍历每个 CUT
for r = 1:Mr
    for c = 1:Mc
        % 总域范围
        r1 = max(1, r - (Tr + Gr)); r2 = min(Mr, r + (Tr + Gr));
        c1 = max(1, c - (Tc + Gc)); c2 = min(Mc, c + (Tc + Gc));
        region = data2d(r1:r2, c1:c2);
        % 把 guard + CUT 清零（不计入训练单元）
        gr1 = max(1, r - Gr); gr2 = min(Mr, r + Gr);
        gc1 = max(1, c - Gc); gc2 = min(Mc, c + Gc);
        region((gr1 - r1 + 1):(gr2 - r1 + 1), (gc1 - c1 + 1):(gc2 - c1 + 1)) = 0;
        % 计算实际训练单元个数
        N_actual = numel(region) - (gr2 - gr1 + 1) * (gc2 - gc1 + 1);
        if N_actual <= 0
            thresholdMap(r,c) = Inf;
            continue;
        end
        noiseLevel = sum(region(:));
        noiseAvg = noiseLevel / N_actual;
        threshold = alpha * noiseAvg;
        thresholdMap(r,c) = threshold;
        if data2d(r,c) > threshold
            detections(r,c) = 1;
        end
    end
end
end