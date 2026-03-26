function test804()
clear all;close all;clc
% ======== 用户参数 ========
port           = "COM5";  % 串口号
chirpsPerFrame = 128;      % 每帧 chirp 数
% ==========================

%% 初始化
% 初始参数
sumt=0;
p = setRadarParameters721();
rdr = read_Raw_serial(port, chirpsPerFrame);
axis_info = setaxis(p);
UsefulSampleNum = find(axis_info.range>p.rangecut, 1);
axis_info.range(UsefulSampleNum:end) = [];
UsefulChirpNumF = find(axis_info.velocity<-p.velocitycut, 1, 'last');
UsefulChirpNumL = find(axis_info.velocity>p.velocitycut, 1, "first");
axis_info.velocity([1:UsefulChirpNumF, UsefulChirpNumL:p.Chirps * p.Nfft]) = [];
% 初始化目标
MAX_target = 100;
for i = 1:MAX_target
    Person(i).ID = i;
    Person(i).Color = [0 0 0];
    Person(i).R = 0;    % 距离
    Person(i).S = 0;    % 状态
    Person(i).T = 0;    % 静止时间
    Person(i).Data = [];  % 保存静止时的 fft1dData
    Person(i).breathRate = 0;
    Person(i).heartRate = 0;
end
% 初始化绘图窗口
[~, axTrack] = initTrackFigure(p);
hTextList = [];
% 帧率显示初始化
frameTimeBuffer = [];
frameTimeBufferSize = 30; % 用于计算平均帧率的缓冲区大小
hFrameRateText = text(axTrack, 0.02, 0.98, '', 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 12, 'Color', 'red', ...
    'BackgroundColor', 'white', 'EdgeColor', 'black');
% 初始化EKF
colorIndex = 1;
draw = 1;
activetagets = [1 1 1 1 1 1 1 1];
ekfinput = [];
% 去多径+测呼吸初始化
Buffer = [];

%% 开始处理
jframe = 0;  %初始化帧计数值
while true
    %% 帧率计算开始
    frameStartTime = tic;
    %% 数据读取
    % ---- 读一帧 ----
    % 强制更新显示


    [rx0Cell, rx1Cell, ~, hasMore] = rdr.readFrame();
    if ~hasMore
        disp("数据读取完毕，退出循环");  break;
    end
    jframe = jframe + 1;

    %每隔100帧清空一次缓冲区，防止延后
        if mod(jframe, 300) == 0
            disp("清空串口缓存");
            rdr.clear_buffer();
        end

    %% 雷达信号处理
    frameData = zeros(1, p.Chirps, 2, p.fftSamples);
    for c = 1:p.Chirps
        frameData(1, c, 1, :) = rx0Cell{c};
        frameData(1, c, 2, :) = rx1Cell{c};
    end
    oneFrame = frameData;
    % 1dfft
    ifft1dData = ifft(oneFrame, [], 4);
    fft1dData = fft1dwindow(ifft1dData, p.fft1dwindowType, p.Nfft);
    fft1dData(:,:,:,UsefulSampleNum:end) = [];
    % MTI
    MTIdata = MTI(fft1dData, p.MTIType);
    % 2dfft
    fft2dData = fft2dwindow(MTIdata, p.fft2dwindowType, p.Nfft);
    fft2dData(:,[1:UsefulChirpNumF, UsefulChirpNumL:p.Chirps * p.Nfft],:,:) = [];
    % NCA
    NCAdata = squeeze(sum(fft2dData, 3));
    NCAdata = reshape(NCAdata, [1, size(NCAdata)]);
    % AAC
    AACdata = applyAmplitudeCompensation(NCAdata);
    % DN
    lossR = mean(db(AACdata),"all") + 10;
    DNdata = DenoisingRD(lossR, p.lossD, axis_info, AACdata);
    
    if ~isempty(activetagets)
        %% 人员状态更新
        [Person, activePersonList] = updatePersonStates(Person, activetagets, fft1dData, axis_info, p);

        if mod(jframe, 30) == 1
        %% 绘制表格
        hTextList = drawPersonStatusTable(axTrack, activePersonList, hTextList);
        end
    end
    %% GMSD检测
    cfarIdx = processCFARDetection(p.N_target, p.suppressWin, p.energyThresh, p.epsilon, p.minPts, DNdata);

    if ~isempty(cfarIdx)
        %% 角度估计
        DoA = estimateDoA(cfarIdx, p, fft2dData);

        %% 位置建模
        observations = PositionModel(cfarIdx, axis_info, DoA(:, 2));

        %% 多径消除滤波
        observations(:, 1) = jframe;
        windowsize = 3;
        Buffer = [Buffer; observations];
        if size(Buffer, 1) > windowsize
            Buffer(Buffer(:, 1) == jframe-windowsize, :) = [];      % 删除最旧的那一行（先进先出）
        end
        observations_filterd = mutlpathfilt(Buffer, p);     % 去除多径
        if ~isempty(observations_filterd)
            observations_filterd(observations_filterd(:, 1) ~= jframe, :) = [];
        end
        if ~isempty(observations_filterd)
            ekfinput = frame_dbscan(observations_filterd, 0.6, 1);
            ekfinput = ekfinput(:, 2:5);
        else, ekfinput = [];
        end
    end

    %% 轨迹跟踪
    if ~isempty(ekfinput)
        figure(1);dian = plot(ekfinput(:,1),ekfinput(:,2),'ro');
        pause(0.02);
        delete(dian);
    end
    targets = tracks_ultra(ekfinput ,p);
    % activetagets[轨迹id x y state R G B num]
    [activetagets, colorIndex] = updateTracks(targets, jframe, p, colorIndex, draw);
    drawnow limitrate;
    %% 帧率更新函数
    frameTimeBuffer = updateFrameRate(frameStartTime, frameTimeBuffer, frameTimeBufferSize, hFrameRateText);
end
%% 关闭串口
rdr.close();
disp("程序结束，串口已关闭");


end