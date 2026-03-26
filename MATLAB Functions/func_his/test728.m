function test728()
% ======== 用户参数 ========
port           = "COM5";  % 串口号
chirpsPerFrame = 128;      % 每帧 chirp 数
drawEveryN     = 1;       % 每 N 帧更新一次曲线，可减小 UI 压力
% ==========================

%% 初始化
% 初始参数
p = setRadarParameters721();
axis_info = setaxis(p);
axis_info.time = (1:FrameNum) * p.frameTime;
% 初始化轨迹图像窗口
[figTrack, axTrack] = initTrackFigure(p);
hTextList = [];
% 轨迹信息
colorIndex = 1;
personNum = [];
tracks = [];
draw = 1;
% 去多径+测呼吸缓存
Buffer = [];
dataBuffer = [];
stateCount = zeros([1 p.N_target]);
breathRate = zeros([1 p.N_target]);
heartRate = zeros([1 p.N_target]);

%% 裁剪数据
UsefulSampleNum = find(axis_info.range>p.rangecut, 1);
axis_info.range(UsefulSampleNum:end) = [];
UsefulChirpNumF = find(axis_info.velocity<-p.velocitycut, 1, 'last');
UsefulChirpNumL = find(axis_info.velocity>p.velocitycut, 1, "first");
axis_info.velocity([1:UsefulChirpNumF, UsefulChirpNumL:p.Chirps * p.Nfft]) = [];

%% 开始处理
jframe = 0;
while true
    %% 数据读取
    tStart = tic;
    % ---- 读一帧 ----
    [rx0Cell, rx1Cell, ~, hasMore] = rdr.readFrame();
    if ~hasMore
        disp("数据读取完毕，退出循环");  break;
    end
    jframe = jframe + 1;

    %每隔10帧清空一次缓冲区，防止延后
    %         if mod(frameCnt, 30) == 0
    %             disp("清空串口缓存");
    %             rdr.clear_buffer();
    %         end

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
    DNdata = DenoisingRD(p.lossR, p.lossD, axis_info, AACdata);

    %% GMSD检测
    cfarIdx = processCFARDetection(p.N_target, p.suppressWin, p.energyThresh, p.epsilon, p.minPts, DNdata);
    if isempty(cfarIdx)
        disp('no tag');
        continue;
    end

    %% 角度估计
    DoA = estimateDoA(cfarIdx, p, fft2dData);

    %% 位置建模
    observations = PositionModel(cfarIdx, axis_info, DoA(:, 2));
    for tagIdx = 1:size(observations,1)
        plot(axTrack, observations(tagIdx, 2), observations(tagIdx, 3), 'b*');
    end

    %% 多径消除滤波
    observations(:, 1) = jframe;
    windowsize = 3;
    Buffer = [Buffer; observations];
    if size(Buffer, 1) > windowsize
        Buffer(Buffer(:, 1) == jframe-windowsize, :) = [];      % 删除最旧的那一行（先进先出）
    end
    observations_filterd = mutlpathfilt(Buffer, p);
    if ~isempty(observations_filterd)
        observations_filterd(observations_filterd(:, 1) ~= jframe, :) = [];
        if isempty(observations_filterd), disp('no tag');continue;end
    else, disp('no tag');continue;
    end
    plot(axTrack, observations_filterd(:, 2), observations_filterd(:, 3), 'g+');
    ekfinput = frame_dbscan(observations_filterd, 0.6, 1);
    plot(axTrack, ekfinput(:, 2), ekfinput(:, 3), 'ro');
    ekfinput = ekfinput(:, 2:5);

    %% 轨迹跟踪
    targets = tracks_ultra(ekfinput ,p);
    % activetagets[轨迹id x y state R G B num]
    [activetagets, colorIndex] = updateTracks(targets, jframe, p, colorIndex, draw);

    %% 呼吸率检测
    % 静止状态保持计数
    personID = targets(targets(:, 4) == 1, 1);
    flag = 1;
    for id = 1:10
        if ismember(id, personID)
            stateCount(id) = stateCount(id) + 1;  % 连续出现，累加
            dataBuffer = [dataBuffer; fft1dData];
            flag = 0;
        else, stateCount(id) = 0;  % 中断，归零
        end
        if flag, dataBuffer = [];end
    end
    stateID = find(stateCount == 50);
    if ~isempty(stateID)
        vct = targets(:, 1) == stateID;
        distance = sqrt(targets(vct, 2) ^ 2 + targets(vct, 3) ^ 2);
        [~, distanceIdx] = min(abs(axis_info.range -  distance ));
        rangeBin = dataBuffer(:, 32, 1, distanceIdx);
        [breathRate(stateID), heartRate(stateID), ~] = get_heartBreath_rate(rangeBin, 1/p.frameTime);
        stateCount = 0;
        dataBuffer = [];
    end

    %% 绘制表格
    hTextList = drawPersonStatusTable(axTrack, activetagets, breathRate, heartRate, hTextList);
end

%% 关闭串口
rdr.close();
disp("程序结束，串口已关闭");
end