function parameter = setRadarParameters()
% 设置基础雷达参数
parameter.frameWindow = 1;
parameter.c = 3e8;                  % 光速
parameter.stratFreq = 24.025e9;     % 起始频率
parameter.Tr = 420e-6;              % chirp上升时间
parameter.Tc = 1200e-6;              % chirp间隔时间
parameter.Fs = 2.5e6;               % 采样率
parameter.Dsample = 4;              % 降采样倍数
parameter.Chirps = 16;              % chirp数
parameter.frameTime = 50e-3;      % 帧时间
parameter.Bandwidth = 240e6;        % 发射信号有效带宽
parameter.Samples = 256;            % 采样点
parameter.fftSamples = 128;            % 1dfft采样点

parameter.Fs = parameter.Fs / parameter.Dsample;    % 真实采样率
parameter.Slope = parameter.Bandwidth / parameter.Tr;                       %chirp斜率
parameter.BandwidthValid = parameter.Samples/parameter.Fs*parameter.Slope;  %发射信号带宽
parameter.centerFreq = parameter.stratFreq + parameter.Bandwidth / 2;       %中心频率
parameter.lambda = parameter.c / parameter.centerFreq;                      %波长

parameter.txAntenna = ones(1,1); % 发射天线个数(1,N)
parameter.rxAntenna = ones(1,2); % 接收天线个数(1,N)
parameter.txNum = length(parameter.txAntenna);
parameter.rxNum = length(parameter.rxAntenna);
parameter.virtualAntenna = length(parameter.txAntenna) * length(parameter.rxAntenna);
parameter.dx = parameter.lambda / 2; % 接收天线水平间距

% 设置信号处理参数
% 预处理部分
parameter.rangecut = 12;            % 距离保留位
parameter.velocitycut = 5;             % 速度保留位
parameter.doaMethod = 1;            % 测角方法选择 1-dbf  2-fft  3-capon
parameter.Nfft = 4;                     % fft点数倍率
parameter.fft1dwindowType = 2;      % 1dfft窗形式 0-no  1-hann  2-hamming  3-blackman
parameter.fft2dwindowType = 1;      % 2dfft窗形式 0-no  1-hann  2-hamming  3-blackman
parameter.MTIType = 1;              % MTI方法 1-均值  2-双脉冲  3-三脉冲
parameter.lossR = 50;                % 滤除杂波
parameter.lossD = 0;                % 滤除杂波
% 检测部分
parameter.N_target = 20;            % 每帧检测目标数
parameter.suppressWin = [2, 2];     % 抑制窗口大小
parameter.energyThresh = 1e2;       % 根据幅度范围设定阈值
parameter.epsilon = 5;              % DBSCAN 的邻域半径（可以根据需要调整）
parameter.minPts = 5;               % DBSCAN 中的最小点数（可以根据需要调整）
parameter.costThreshold = 3;       % 数据关联阈值
parameter.predictionframe = 5;       % 使用最近多少帧历史信息进行预测
parameter.dr = 0.1;                     % 多径消除距离阈值
parameter.de = 0.2;                     % 角度阈值
% 帧关联参数
parameter.epsilon1 = 0.8;               % 邻域半径
parameter.minPoints1 = 3;               % 形成簇的最小点数
parameter.related_FrameNum = 10; % 关联帧数
% 跟踪部分
parameter.reset = 0;                        % 选择是否使用EKF进行目标轨迹预测，1清零，0工作

% 轨迹历史容器（限制长度的轨迹点）
parameter.historyMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
% 轨迹完整历史容器（存储所有轨迹点）
parameter.fullHistoryMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
% 轨迹最后更新时间
parameter.lastUpdateMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
% 图形句柄
parameter.lineHandles = containers.Map('KeyType', 'double', 'ValueType', 'any');
parameter.pointHandles = containers.Map('KeyType', 'double', 'ValueType', 'any');
% 轨迹颜色映射
parameter.colorMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
% 导入测试场景
parameter.PersonNum = 1;
parameter.testscene = 4;                % Rooftop = 1;
if parameter.testscene == 1
    parameter.x = [-3 3];
    parameter.y = [1 8];
elseif parameter.testscene == 2     % Corridor = 2;
    parameter.x = [-3.62 3.81];
    parameter.y = [-1.66 4.57];
elseif parameter.testscene == 3     % Room = 3;
    parameter.x = [-3.62 3.81];
    parameter.y = [-1.66 4.57];
elseif parameter.testscene == 4     % kb406 = 4;
    parameter.x = [-0.5 0.5];
    parameter.y = [1 3];
else
    error('wrong scene');
end

end
