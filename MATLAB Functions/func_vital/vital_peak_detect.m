function [resp_freq_est, heart_freq_est] = vital_peak_detect(freq_pos, fft_amp, param)
% 函数功能：从生命体征频谱中快速寻峰，估计呼吸频率和心率（单位：Hz）
% 输入参数：
%   freq_pos - 一维向量，正频率轴（0~Fs/2，单位：Hz）
%   fft_amp  - 一维向量，与freq_pos对应的归一化频谱幅度谱
%   param    - 嵌套结构体，包含生命体征的呼吸/心率区间配置（次/分钟）
% 输出参数：
%   resp_freq_est - 估计的呼吸频率（单位：Hz）
%   heart_freq_est - 估计的心率（单位：Hz）

%% 1. 从param中提取呼吸/心率区间（次/分钟），并转换为Hz（生理频率区间）
% 呼吸率区间（次/分钟→Hz）：除以60完成单位转换
resp_br_range_bpm = param.vital.BR_range;  % 提取呼吸率上下限（次/分钟），如[8, 20]
resp_freq_min = resp_br_range_bpm(1) / 60; % 呼吸最低频率（Hz）
resp_freq_max = resp_br_range_bpm(2) / 60; % 呼吸最高频率（Hz）

% 心率区间（次/分钟→Hz）：除以60完成单位转换
resp_hr_range_bpm = param.vital.HR_range;  % 提取心率上下限（次/分钟），如[60, 100]
heart_freq_min = resp_hr_range_bpm(1) / 60; % 心率最低频率（Hz）
heart_freq_max = resp_hr_range_bpm(2) / 60; % 心率最高频率（Hz）

%% 2. 筛选呼吸频率区间内的频谱数据
resp_mask = (freq_pos >= resp_freq_min) & (freq_pos <= resp_freq_max);
resp_freq_valid = freq_pos(resp_mask);
resp_amp_valid = fft_amp(resp_mask);

%% 3. 筛选心率频率区间内的频谱数据
heart_mask = (freq_pos >= heart_freq_min) & (freq_pos <= heart_freq_max);
heart_freq_valid = freq_pos(heart_mask);
heart_amp_valid = fft_amp(heart_mask);

%% 4. 简化寻峰逻辑（找幅度最大的点作为峰值，鲁棒性保障）
% 呼吸频率寻峰（无有效数据时，用param呼吸率均值换算为Hz作为默认值）
if ~isempty(resp_amp_valid)
    [~, resp_max_idx] = max(resp_amp_valid);
    resp_freq_est = resp_freq_valid(resp_max_idx);
else
    resp_freq_est = mean(resp_br_range_bpm) / 60;
end

% 心率频率寻峰（无有效数据时，用param心率均值换算为Hz作为默认值）
if ~isempty(heart_amp_valid)
    [~, heart_max_idx] = max(heart_amp_valid);
    heart_freq_est = heart_freq_valid(heart_max_idx);
else
    heart_freq_est = mean(resp_hr_range_bpm) / 60;
end

end