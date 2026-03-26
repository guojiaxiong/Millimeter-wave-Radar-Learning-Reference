function [diff_ag, dcRemove_ag, unwrap_dcRemove_ag] = phase_unwrap(complex_signal, slowtime_fs, phase_unwrap_method)
% PHASE_UNWRAP_PROCESS 相位解缠绕独立处理函数（修复输出参数未赋值错误）
% 输入：
%   complex_signal     - 目标复信号（一维数组）
%   slowtime_fs        - 慢时间采样率（Hz）
%   phase_unwrap_method - 解缠绕方法：'unwrap'/'dacm'
% 输出：
%   diff_ag            - 差分后的相位信号
%   dcRemove_ag        - 原始相位（dacm分支补全赋值）
%   unwrap_dcRemove_ag - 解缠绕后的相位

N = length(complex_signal);

switch phase_unwrap_method
    case 'unwrap'
        dcRemove_ag = angle(complex_signal);  % 原赋值保留
        unwrap_dcRemove_ag = unwrap(dcRemove_ag);
        diff_ag = unwrap_dcRemove_ag(1:end-1) - unwrap_dcRemove_ag(2:end);

    case 'dacm'
        % 1. 补全dcRemove_ag赋值（与unwrap分支逻辑对齐，取复信号的原始相位）
        dcRemove_ag = angle(complex_signal);  % 关键修复：给dcRemove_ag赋值
        % 2. 原dacm逻辑完全保留
        R = abs(complex_signal);
        I = imag(complex_signal);
        dt = 1/slowtime_fs;
        omega = zeros(N, 1);
        for m = 2:N
            numerator = R(m) * (I(m) - I(m-1)) - (R(m) - R(m-1)) * I(m);
            denominator = R(m)^2 + I(m)^2;
            omega(m) = numerator / denominator / dt;
        end
        phi = zeros(N, 1);
        for m = 2:N
            phi(m) = phi(m-1) + omega(m) * dt;
        end
        unwrap_dcRemove_ag = phi;  % 原赋值保留
        phi_diff = zeros(N-1, 1);
        for m = 2:N
            phi_diff(m-1) = phi(m) - phi(m-1);
        end
        diff_ag = phi_diff - mean(phi_diff);  % 原赋值保留

    otherwise
        error('相位解缠绕算法选择错误！仅支持''unwrap''或''dacm''');
end

end