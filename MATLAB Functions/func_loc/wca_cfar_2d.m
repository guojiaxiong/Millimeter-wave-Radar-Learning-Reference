function [detections, thresholdMap] = wca_cfar_2d(data2d, Tr, Tc, Gr, Gc, Pfa)
% WCA-CFAR (Weighted Cell Averaging CFAR) 2D 实现
% data2d: 输入功率矩阵 (rows: range, cols: doppler)
% Tr,Tc: 训练单元半宽 (range,doppler)
% Gr,Gc: guard 半宽
% Pfa: 期望虚警率
% 返回 detections (二值) 与 thresholdMap (线性阈值)
[Mr, Mc] = size(data2d);
detections = zeros(Mr, Mc);
thresholdMap = zeros(Mr, Mc);

% 训练单元总数（近似）
Ntrain = (2*Tr+1)*(2*Tc+1) - (2*Gr+1)*(2*Gc+1);
if Ntrain <= 0
    error('训练单元数量 <= 0，请增大 Tr 或 Tc');
end
% alpha 近似（同 CA-CFAR）
alpha = Ntrain * (Pfa^(-1/Ntrain) - 1);

% 预计算训练窗口坐标权重：距离越近权重越大（简单倒数权重）
% 为避免除零，权重使用 sqrt( dr^2 + dc^2 ) + eps
% 这里给出一个局部权重模板（2*(Tr+Gr)+1 by 2*(Tc+Gc)+1）
rR = - (Tr+Gr) : (Tr+Gr);
cC = - (Tc+Gc) : (Tc+Gc);
[RR, CC] = ndgrid(rR, cC);
dist = sqrt(RR.^2 + CC.^2) + eps;
% 保护区他处的权重会被置为 zero later
w_template = 1./dist;                     % 倒数权（可调）
w_template(RR >= -Gr & RR <= Gr & CC >= -Gc & CC <= Gc) = 0; % guard+CUT 置0

for r = 1:Mr
    for c = 1:Mc
        r1 = max(1, r - (Tr + Gr)); r2 = min(Mr, r + (Tr + Gr));
        c1 = max(1, c - (Tc + Gc)); c2 = min(Mc, c + (Tc + Gc));
        region = data2d(r1:r2, c1:c2);
        % 对应的权重子模板
        sub_rR = (r1 - r) : (r2 - r);
        sub_cC = (c1 - c) : (c2 - c);
        [SR, SC] = ndgrid(sub_rR, sub_cC);
        dist_sub = sqrt(SR.^2 + SC.^2) + eps;
        w_sub = 1 ./ dist_sub;
        % 将 guard+CUT 区域权重设为0
        gr1 = max(1, r - Gr); gr2 = min(Mr, r + Gr);
        gc1 = max(1, c - Gc); gc2 = min(Mc, c + Gc);
        g_r1 = gr1 - r1 + 1; g_r2 = gr2 - r1 + 1;
        g_c1 = gc1 - c1 + 1; g_c2 = gc2 - c1 + 1;
        w_sub(g_r1:g_r2, g_c1:g_c2) = 0;
        % 计算加权噪声估计（权重归一化）
        Wsum = sum(w_sub(:));
        if Wsum <= 0
            thresholdMap(r,c) = Inf; continue;
        end
        noiseAvg = sum(sum(region .* w_sub)) / Wsum;
        threshold = alpha * noiseAvg;
        thresholdMap(r,c) = threshold;
        if data2d(r,c) > threshold
            detections(r,c) = 1;
        end
    end
end
end
