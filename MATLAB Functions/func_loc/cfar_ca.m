function target_idx = cfar_ca(rd_2d, cfar)
% CFAR_CA_2D 二维RD图CA-CFAR检测（仅输出目标索引，无绘图）
% 用法:
%   target_idx = cfar_ca(rd_2d)                  % 默认CFAR参数
%   target_idx = cfar_ca(rd_2d, N_d, N_r, G_d, G_r, alpha, power_thresh)
% 输入参数:
%   rd_2d         - 二维RD图矩阵 [doppler_len × range_len]（chirp×sample）
%   N_d           - 可选，多普勒方向参考单元数，默认12
%   N_r           - 可选，距离方向参考单元数，默认8
%   G_d           - 可选，多普勒方向保护单元数，默认5
%   G_r           - 可选，距离方向保护单元数，默认2
%   alpha         - 可选，功率阈值因子（门限=参考窗均值×alpha），默认2.0
%   power_thresh  - 可选，功率前置阈值（仅对幅值>该值的点执行CFAR），默认0
% 输出参数:
%   target_idx    - [N×3]矩阵，每行=[x坐标(rangeIdx), y坐标(dopplerIdx), 功率]，N为检测到的目标数

N_d = cfar.N_d;
N_r = cfar.N_r;
G_d = cfar.G_d;
G_r = cfar.G_r;
alpha = cfar.alpha;
power_thresh = cfar.power_thresh;

[doppler_len, range_len] = size(rd_2d);


rd_amp = abs(rd_2d);
target_idx = [];

for dopplerIdx = 1:doppler_len
    for rangeIdx = 1:range_len
        current_amp = rd_amp(dopplerIdx, rangeIdx);
        if current_amp <= power_thresh
            continue;
        end
        
        d_start = max(1, dopplerIdx - G_d - N_d);
        d_end = min(doppler_len, dopplerIdx + G_d + N_d);
        r_start = max(1, rangeIdx - G_r - N_r);
        r_end = min(range_len, rangeIdx + G_r + N_r);
        
        [D, R] = meshgrid(d_start:d_end, r_start:r_end);
        mask = true(size(D));
        mask((D >= dopplerIdx - G_d) & (D <= dopplerIdx + G_d) & ...
             (R >= rangeIdx - G_r) & (R <= rangeIdx + G_r)) = false;
        
        ref_window = rd_amp(D(mask), R(mask));
        ref_mean = mean(ref_window(:));
        
        if current_amp > ref_mean * alpha
            target_idx = [target_idx; rangeIdx, dopplerIdx, current_amp];
        end
    end
end

if isempty(target_idx)
    disp('【检测阶段】未检测到目标！');
    target_idx = [];
end

end