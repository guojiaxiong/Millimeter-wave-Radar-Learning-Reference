function axis_info = setAxis(param)
    % 函数功能：生成雷达距离/多普勒/时间轴（适配param_config的嵌套参数结构）
    % 输入参数：
    %   param        - 嵌套结构体（param_config的输出），包含雷达系统所有配置
    % 输出参数：
    %   axis_info    - 结构体，包含距离轴、多普勒轴、时间轴
    
    %% ========== 核心：参数映射转换（对齐param_config的嵌套字段） ==========
    % 1. 固定物理常量
    p.c = 3e8;                              % 光速（m/s），雷达计算核心常量
    
    % 2. 从param.radar映射setAxis所需的核心参数（一一对应）
    p.Slope = param.radar.S;                % 啁啾斜率（对应param.radar.S）
    p.Fs = param.radar.Fs_radar;            % 采样率（对应param.radar.Fs_radar）
    p.Samples = param.radar.N_Sample;       % 单Chirp采样点数（对应param.radar.N_Sample）
    p.Tc = param.radar.PRI;                 % Chirp周期（对应param.radar.PRI）
    p.Chirps = param.radar.N_Chirp;         % 单帧Chirp数（对应param.radar.N_Chirp）
    p.lambda = param.radar.lambda;          % 雷达波长（对应param.radar.lambda）
    p.numFrames = param.radar.N_Frame;      % 总帧数（对应param.radar.N_Frame）
    p.frameTime = 1 / param.radar.FPS;      % 单帧总时间（对应param.radar.T_frame）
    p.Nfft = 1;                      % 默认FFT点数（补零后）


    %% ========== 原有轴计算逻辑（无需修改） ==========
    % 距离轴
    range_res = p.c * p.Fs / (2 * p.Slope * p.Samples * p.Nfft);    % 距离分辨率
    range_axis = (0:p.Samples * p.Nfft-1) * range_res;              % 距离坐标轴
    % 多普勒轴
    fd_max = 1 / (2 * p.Tc);                                        % 最大多普勒频率（Hz）
    fd_axis = linspace(-fd_max, fd_max, p.Chirps * p.Nfft);         % 多普勒频率轴
    velocity_axis = fd_axis * p.lambda / 2;                         % 速度 (v = fd * p.lambda / 2)
    % 时间轴
    time_axis = (1:p.numFrames) * p.frameTime;                      % 时间轴
    % 保存三轴
    axis_info.range = range_axis;
    axis_info.velocity = velocity_axis;
    axis_info.time = time_axis;
end