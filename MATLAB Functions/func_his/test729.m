function test729()
clear all;close all;clc
% ======== 用户参数 ========
port           = "COM5";  % 串口号
chirpsPerFrame = 128;      % 每帧 chirp 数
drawEveryN     = 1;       % 每 N 帧更新一次曲线，可减小 UI 压力
% ==========================

%% 初始化
% 初始参数
p = setRadarParameters721();
axis_info = setaxis(p);
rdr = read_Raw_serial(port, chirpsPerFrame);

% 初始化轨迹图像窗口
[~, axTrack] = initTrackFigure(p);

% 帧率显示初始化
frameTimeBuffer = [];
frameTimeBufferSize = 30; % 用于计算平均帧率的缓冲区大小
hFrameRateText = text(axTrack, 0.02, 0.98, '', 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 12, 'Color', 'red', ...
    'BackgroundColor', 'white', 'EdgeColor', 'black');

% 优化绘图结构 - 预分配绘图句柄
maxPoints = 1000; % 最大显示点数
hObservations = plot(axTrack, NaN, NaN, 'b*', 'MarkerSize', 6);
hFilteredObs = plot(axTrack, NaN, NaN, 'g+', 'MarkerSize', 8);
hTargets = plot(axTrack, NaN, NaN, 'ro', 'MarkerSize', 8, 'LineWidth', 2);

% 数据缓冲区用于绘图
obsBuffer = NaN(maxPoints, 2);
filteredBuffer = NaN(maxPoints, 2);
targetBuffer = NaN(maxPoints, 2);
obsCount = 0;
filteredCount = 0;
targetCount = 0;

hTextList = [];
% 轨迹信息
colorIndex = 1;
personNum = [];
tracks = [];
targetsHistory = [];
draw = 1;
targets = [0 0 0 0];
activetagets = [1 1 1 1 1 1 1 1];
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

    %% 帧率计算开始
    frameStartTime = tic;

    %% 数据读取
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
    %% 呼吸率检测
    % 静止状态保持计数
    personID = targets(targets(:, 4) == 1, 1);
    if ~isempty(personID)
        stateCount(personID) = stateCount(personID) + 1;  % 连续出现，累加
        t = setdiff(personID, 1:p.N_target);
        stateCount(t) = 0;
        dataBuffer = [dataBuffer; fft1dData];
        size(dataBuffer);
    else,stateCount = zeros([1 p.N_target]);dataBuffer = [];  % 中断，归零
    end
    stateID = find(stateCount == 50);
    if ~isempty(stateID)
        vct = targets(targets(:, 1) == stateID', 1)
        for jstill = 1:length(vct)
            distance = sqrt(targets(targets(:, 1) == vct(jstill), 2) ^ 2 + targets(targets(:, 1) == vct(jstill), 3) ^ 2);
            [~, distanceIdx] = min(abs(axis_info.range -  distance ));
            rangeBin = dataBuffer(:, 32, 1, distanceIdx);
            [breathRate(jstill), heartRate(jstill), ~] = get_heartBreath_rate(rangeBin, 1/p.frameTime);
        end
        stateCount = zeros([1 p.N_target]);
        dataBuffer = [];
    end
    %% 绘制表格
    hTextList = drawPersonStatusTable(axTrack, activetagets, breathRate, heartRate, hTextList);

    %% GMSD检测
    cfarIdx = processCFARDetection(p.N_target, p.suppressWin, p.energyThresh, p.epsilon, p.minPts, DNdata);
    if isempty(cfarIdx)
        disp('no tag');
        % 更新帧率显示
        updateFrameRate(frameStartTime, frameTimeBuffer, frameTimeBufferSize, hFrameRateText);
        continue;
    end

    %% 角度估计
    DoA = estimateDoA(cfarIdx, p, fft2dData);

    %% 位置建模
    observations = PositionModel(cfarIdx, axis_info, DoA(:, 2));

    % 优化绘图 - 更新观测点数据
    if ~isempty(observations) && mod(jframe, drawEveryN) == 0
        numObs = size(observations, 1);
        if obsCount + numObs > maxPoints
            % 循环缓冲区
            obsBuffer = circshift(obsBuffer, -numObs);
            obsBuffer(end-numObs+1:end, :) = observations(:, [2, 3]);
            obsCount = maxPoints;
        else
            obsBuffer(obsCount+1:obsCount+numObs, :) = observations(:, [2, 3]);
            obsCount = obsCount + numObs;
        end
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
        if isempty(observations_filterd), disp('no tag');
            updateFrameRate(frameStartTime, frameTimeBuffer, frameTimeBufferSize, hFrameRateText);
            continue;
        end
    else, disp('no tag');
        updateFrameRate(frameStartTime, frameTimeBuffer, frameTimeBufferSize, hFrameRateText);
        continue;
    end

    % 优化绘图 - 更新滤波后观测点数据
    if ~isempty(observations_filterd) && mod(jframe, drawEveryN) == 0
        numFiltered = size(observations_filterd, 1);
        if filteredCount + numFiltered > maxPoints
            filteredBuffer = circshift(filteredBuffer, -numFiltered);
            filteredBuffer(end-numFiltered+1:end, :) = observations_filterd(:, [2, 3]);
            filteredCount = maxPoints;
        else
            filteredBuffer(filteredCount+1:filteredCount+numFiltered, :) = observations_filterd(:, [2, 3]);
            filteredCount = filteredCount + numFiltered;
        end
    end

    ekfinput = frame_dbscan(observations_filterd, 0.6, 1);

    % 优化绘图 - 更新目标点数据
    if ~isempty(ekfinput) && mod(jframe, drawEveryN) == 0
        numTargets = size(ekfinput, 1);
        if targetCount + numTargets > maxPoints
            targetBuffer = circshift(targetBuffer, -numTargets);
            targetBuffer(end-numTargets+1:end, :) = ekfinput(:, [2, 3]);
            targetCount = maxPoints;
        else
            targetBuffer(targetCount+1:targetCount+numTargets, :) = ekfinput(:, [2, 3]);
            targetCount = targetCount + numTargets;
        end
    end

    ekfinput = ekfinput(:, 2:5);

    %% 轨迹跟踪
    targets = tracks_ultra(ekfinput ,p);
    % activetagets[轨迹id x y state R G B num]
    [activetagets, colorIndex] = updateTracks(targets, jframe, p, colorIndex, draw);


    %% 优化绘图更新
    if mod(jframe, drawEveryN) == 0
        % 更新绘图数据
        %         if obsCount > 0
        %             validObs = ~isnan(obsBuffer(1:obsCount, 1));
        %             set(hObservations, 'XData', obsBuffer(validObs, 1), 'YData', obsBuffer(validObs, 2));
        %         end
        %
        %         if filteredCount > 0
        %             validFiltered = ~isnan(filteredBuffer(1:filteredCount, 1));
        %             set(hFilteredObs, 'XData', filteredBuffer(validFiltered, 1), 'YData', filteredBuffer(validFiltered, 2));
        %         end

        %         if targetCount > 0
        %             validTargets = ~isnan(targetBuffer(1:targetCount, 1));
        %             set(hTargets, 'XData', targetBuffer(validTargets, 1), 'YData', targetBuffer(validTargets, 2));
        %         end

        % 强制更新显示
        drawnow limitrate;
    end

    %% 更新帧率显示
    frameTimeBuffer = updateFrameRate(frameStartTime, frameTimeBuffer, frameTimeBufferSize, hFrameRateText);


end

%% 关闭串口
rdr.close();
disp("程序结束，串口已关闭");
end

%% 帧率更新函数
function frameTimeBuffer = updateFrameRate(frameStartTime, frameTimeBuffer, bufferSize, hFrameRateText)
% 计算当前帧处理时间
currentFrameTime = toc(frameStartTime);

% 更新帧时间缓冲区
frameTimeBuffer = [frameTimeBuffer, currentFrameTime];
if length(frameTimeBuffer) > bufferSize
    frameTimeBuffer = frameTimeBuffer(end-bufferSize+1:end);
end

% 计算平均帧率
avgFrameTime = mean(frameTimeBuffer);
currentFPS = 1 / avgFrameTime;
instantFPS = 1 / currentFrameTime;

% 更新帧率显示
frameRateText = sprintf('FPS: %.1f (平均: %.1f)\n处理时间: %.1f ms', ...
    instantFPS, currentFPS, currentFrameTime * 1000);
set(hFrameRateText, 'String', frameRateText);
end