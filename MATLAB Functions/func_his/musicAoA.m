function [angles_deg, spectrum] = musicAoA(rxSignals, d, lambda, scanAngles, numSignals)
% rxSignals: M × N 矩阵 (M个天线通道，N个样本点)
% d: 天线间距（单位：米）
% lambda: 雷达波长（单位：米）
% scanAngles: 角度扫描范围（单位：度），如 -90:0.5:90
% numSignals: 待估计信号个数（目标数）
% angles_deg: 估计得到的目标角度（单位：度）
% spectrum: MUSIC谱值（用于绘图）

    M = size(rxSignals, 1); % 天线数
    thetaScan = deg2rad(scanAngles); % 扫描角度转为弧度

    % 1. 协方差矩阵
    R = (rxSignals * rxSignals') / size(rxSignals, 2);

    % 2. 特征值分解
    [E, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    E = E(:, idx); % 特征向量按特征值大小排序

    % 3. 提取噪声子空间
    En = E(:, numSignals+1:end); % 取后 M-K 个特征向量

    % 4. MUSIC谱计算
    spectrum = zeros(length(thetaScan), 1);
    for k = 1:length(thetaScan)
        steeringVec = exp(-1j * 2 * pi * d / lambda * (0:M-1).' * sin(thetaScan(k)));
        spectrum(k) = 1 / (steeringVec' * (En * En') * steeringVec);
    end

    spectrum_dB = 10 * log10(abs(spectrum));
    
    % 5. 角度估计（找谱峰）
    [~, locs] = findpeaks(spectrum_dB, 'SortStr', 'descend', 'NPeaks', numSignals);
    angles_deg = scanAngles(locs);

    % 6. 可视化
    figure;
    plot(scanAngles, spectrum_dB);
    xlabel('Angle (°)');
    ylabel('Pseudo-Spectrum (dB)');
    title('MUSIC AoA Spectrum');
    grid on;
end
