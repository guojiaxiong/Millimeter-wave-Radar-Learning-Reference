function [detections, thresholdMap] = go_cfar_2d(data2d, Tr, Tc, Gr, Gc, Pfa)
% GO-CFAR (Greatest Of CFAR) 2D 实现
% 与 SO-CFAR 相似，但取两侧部分噪声估计的最大值（保守策略，抗噪声突变差）
[Mr, Mc] = size(data2d);
detections = zeros(Mr, Mc);
thresholdMap = zeros(Mr, Mc);

Ntrain = (2*Tr+1)*(2*Tc+1) - (2*Gr+1)*(2*Gc+1);
if Ntrain <= 0
    error('训练单元数量 <= 0，请增大 Tr 或 Tc');
end
alpha = Ntrain * (Pfa^(-1/Ntrain) - 1);

for r = 1:Mr
    for c = 1:Mc
        r1 = max(1, r - (Tr + Gr)); r2 = min(Mr, r + (Tr + Gr));
        c1 = max(1, c - (Tc + Gc)); c2 = min(Mc, c + (Tc + Gc));
        region = data2d(r1:r2, c1:c2);
        
        gr1 = max(1, r - Gr); gr2 = min(Mr, r + Gr);
        gc1 = max(1, c - Gc); gc2 = min(Mc, c + Gc);
        
        % 分区（同 SO 实现）
        left_c1 = c1; left_c2 = max(c1, c - Gc - 1);
        right_c1 = min(c2, c + Gc + 1); right_c2 = c2;
        top_r1 = r1; top_r2 = max(r1, r - Gr - 1);
        bottom_r1 = min(r2, r + Gr + 1); bottom_r2 = r2;
        
        part_left = []; part_right = []; part_top = []; part_bottom = [];
        if left_c2 >= left_c1
            part_left = region(:, (left_c1-c1+1):(left_c2-c1+1));
        end
        if right_c2 >= right_c1
            part_right = region(:, (right_c1-c1+1):(right_c2-c1+1));
        end
        if top_r2 >= top_r1
            part_top = region((top_r1-r1+1):(top_r2-r1+1), :);
        end
        if bottom_r2 >= bottom_r1
            part_bottom = region((bottom_r1-r1+1):(bottom_r2-r1+1), :);
        end
        
        mean_left = Inf; mean_right = Inf; mean_top = Inf; mean_bottom = Inf;
        if ~isempty(part_left)
            mean_left = sum(part_left(:)) / numel(part_left);
        end
        if ~isempty(part_right)
            mean_right = sum(part_right(:)) / numel(part_right);
        end
        if ~isempty(part_top)
            mean_top = sum(part_top(:)) / numel(part_top);
        end
        if ~isempty(part_bottom)
            mean_bottom = sum(part_bottom(:)) / numel(part_bottom);
        end
        
        % 取最大值作为噪声估计（更保守）
        noiseAvg = max([mean_left, mean_right, mean_top, mean_bottom]);
        if ~isfinite(noiseAvg)
            thresholdMap(r,c) = Inf; continue;
        end
        threshold = alpha * noiseAvg;
        thresholdMap(r,c) = threshold;
        if data2d(r,c) > threshold
            detections(r,c) = 1;
        end
    end
end
end
