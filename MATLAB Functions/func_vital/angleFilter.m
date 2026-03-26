function [target_rangeProfile, rangeBin] = angleFilter(doa_rangeProfile, azimuSpectrogram_norm, Rxv, param)
% EXTRACT_TARGET_RANGEPROFILE 从DOA角度谱提取目标距离剖面（MVDR角度滤波）
% 【核心功能】
%   1. 从归一化角度谱中提取目标的角度-距离坐标；
%   2. 基于MVDR算法计算角度滤波权重；
%   3. 对目标所在距离门数据进行角度滤波，输出纯净的目标距离剖面。
% 
% 【输入参数】
%   azimuSpectrogram_norm : 二维矩阵（角度数×距离门数），归一化后的DOA方位角谱
%   param                 : 结构体，包含所有雷达/DOA参数，关键字段：
% 
% 【输出参数】
%   target_rangeProfile   : 二维矩阵（有效Chirp数×目标数量），每个列对应一个目标的角度滤波后距离剖面
% 
% 【依赖函数】
%   findLocalMaximaInIdx.m: 局部最大值提取函数（需提前定义）

    %% 1. 角度谱预处理（翻转对齐角度轴）
    azimuSpectrogram = flipud(azimuSpectrogram_norm);

    %% 2. 提取目标的角度-距离坐标（局部最大值搜索）
    % 搜索窗口尺寸设为45（与原代码一致），提取param.target.num个目标
    rangeBin = findLocalMaximaInIdx(azimuSpectrogram, 45, param.target.num);
    
    %% 3. 关键参数初始化（雷达/DOA参数）
    lambda = param.radar.lambda;       % 雷达波长
    d = lambda / 2;                    % 天线阵元间距（半波长）
    
    %% 4. 初始化目标距离剖面矩阵
    target_rangeProfile = zeros(param.radar.N_Chirp, size(rangeBin, 1));
    
    %% 5. MVDR角度滤波（逐目标处理） 
    for i = 1:size(rangeBin, 1)
        % 5.1 提取目标所在距离门的原始数据
        range_idx = rangeBin(i, 2) - 1; % 目标距离门索引（修正偏移）
        x = squeeze(doa_rangeProfile(:, range_idx, :));
        
        % 5.2 计算目标角度对应的导向矢量
        % 角度索引转真实角度（°）
        detAngle = -param.doa.searchAngleRange + rangeBin(i, 1) * ...
            (param.doa.searchAngleRange * 2 / length(azimuSpectrogram(:, 1)));
        % 相位因子计算（fai = 2πd sinθ/λ）
        fai = 2 * pi * sin(detAngle / 180 * pi) * d / lambda;
        % 8阵元导向矢量（列向量）—— 保留原硬编码
        aTheta = [1,exp(-1j*1*fai),exp(-1j*2*fai),exp(-1j*3*fai),...
                  exp(-1j*4*fai),exp(-1j*5*fai),exp(-1j*6*fai),exp(-1j*7*fai)].';
        
        % 5.3 计算MVDR最优权重并滤波 —— 仅修改这一行（核心错误修正）
        Rxv_inv = inv(Rxv); % 新增：协方差矩阵求逆（MVDR核心）
        Wopt = (Rxv_inv * aTheta) / (aTheta' * Rxv_inv * aTheta); % 修正：用逆矩阵计算
        target_rangeProfile(:, i) = x * Wopt;
    end

end