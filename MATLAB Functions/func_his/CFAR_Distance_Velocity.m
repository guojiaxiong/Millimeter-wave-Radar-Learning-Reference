function cfarOut = CFAR_Distance_Velocity(RDM, alpha_r, alpha_v, NTestr, NTestv, NGuardr, NGuardv, sidelobeThr, Range_peak)
% CFAR_Distance_Velocity 双级CA-CFAR：先Range方向再Doppler方向
% RDM           — M×N 矩阵（第1维速度，第2维距离）
% alpha_r,v     — 两级门限放大因子
% NTestr,v      — 训练单元数
% NGuardr,v     — 保护单元数
% sidelobeThr   — 旁瓣比门限
% Range_peak    — M×1 向量，每个速度bin的峰值

    [M, N] = size(RDM);
    Wr = NTestr  + NGuardr;
    Wv = NTestv  + NGuardv;

    % 预分配
    threshold_r  = zeros(M, N);
    threshold_v  = zeros(M, N);
    noise_r_map  = zeros(M, N);    % 存储每个(i,j)的Range噪声估计
    detect_mask  = false(M, N);
    cfarMap      = zeros(M, N);
    noise_v      = [];
    snr          = [];

    % —————— 第一遍：Range-CFAR ——————
    for i = 1:M
        for j = Wr+1 : N-Wr
            left_avg   = mean( RDM(i, j-Wr : j-NGuardr-1) );
            right_avg  = mean( RDM(i, j+NGuardr+1 : j+Wr) );
            noise_est  = min(left_avg, right_avg);
            thr        = noise_est * alpha_r;
            threshold_r(i,j) = thr;
            if RDM(i,j) > thr
                detect_mask(i,j)   = true;
                noise_r_map(i,j)   = noise_est;
            end
        end
    end

    % —————— 第二遍：Doppler-CFAR + 旁瓣比 ——————
    k = 1;
    for i = Wv+1 : M-Wv
        for j = 1 : N
            if detect_mask(i,j)
                up_avg    = mean( RDM(i-Wv : i-NGuardv-1, j) );
                down_avg  = mean( RDM(i+NGuardv+1 : i+Wv, j) );
                noise_est = min(up_avg, down_avg);
                thr       = noise_est * alpha_v;
                threshold_v(i,j) = thr;
                % 同时满足 Doppler 门限 和 旁瓣比门限
                if RDM(i,j) > thr && RDM(i,j) > Range_peak(i) * sidelobeThr
                    cfarMap(i,j)   = RDM(i,j);
                    noise_v(k)     = noise_est;                          %#ok<AGROW>
                    snr(k)         = RDM(i,j) / (eps + noise_r_map(i,j)); %#ok<AGROW>
                    k = k + 1;
                end
            end
        end
    end

    % —————— 打包输出 ——————
    cfarOut = struct();
    cfarOut.cfarMap     = cfarMap;
    cfarOut.threshold_r = threshold_r;
    cfarOut.threshold_v = threshold_v;
    cfarOut.noise_r_map = noise_r_map;
    cfarOut.noise_v     = noise_v;
    cfarOut.snr         = snr;
end
