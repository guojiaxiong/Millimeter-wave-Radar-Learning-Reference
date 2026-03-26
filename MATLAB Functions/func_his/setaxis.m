function axis_info = setaxis(p)
    % 距离轴
    range_res = p.c * p.Fs / (2 * p.Slope * p.Samples * p.Nfft);    % 距离分辨率
    range_axis = (0:p.fftSamples * p.Nfft-1) * range_res;              % 距离坐标轴
    % 多普勒轴
    fd_max = 1 / (2 * p.Tc);                                        % 最大多普勒频率（Hz）
    fd_axis = linspace(-fd_max, fd_max, p.Chirps * p.Nfft);         % 多普勒频率轴
    velocity_axis = fd_axis * p.lambda / 2;                         % 速度 (v = fd * p.lambda / 2)
    % 时间轴
    time_axis = (1:p.frameWindow) * p.frameTime;                    % 时间轴
    % 保存三轴
    axis_info.range = range_axis;
    axis_info.velocity = velocity_axis;
    axis_info.time = time_axis;
end