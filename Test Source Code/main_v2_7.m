% 实时调试带心率第三版
% 轨迹输入带空数组

%% 读取文件
clc;clear all;close all;
location = 'SpecialSence/';
file = '两人相向1';
filename = [file, '.mat'];
load([location, filename]);
[FrameNum, ChirpNum, RxNum, SampleNum] = size(mergedData);

%% 初始化
% 初始化雷达
p = setRadarParameters721();
axis_info = setaxis(p);
axis_info.time = (1:FrameNum) * p.frameTime;
UsefulSampleNum = find(axis_info.range>p.rangecut, 1);
axis_info.range(UsefulSampleNum:end) = [];
UsefulChirpNumF = find(axis_info.velocity<-p.velocitycut, 1, 'last');
UsefulChirpNumL = find(axis_info.velocity>p.velocitycut, 1, "first");
axis_info.velocity([1:UsefulChirpNumF, UsefulChirpNumL:p.Chirps * p.Nfft]) = [];
% 初始化目标
MAX_target = 100;
defaultPerson = struct( ...
    'ID', 0, ...
    'Color', [0 0 0], ...
    'R', 0, ...
    'S', 0, ...
    'T', 0, ...
    'Data', [], ...
    'breathRate', 0, ...
    'heartRate', 0);
Person = repmat(defaultPerson, 1, MAX_target);
for i = 1:MAX_target
    Person(i).ID = i;
end
% 初始化绘图窗口
[hPoint, axTrack] = initTrackFigure(p);
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
targets = [0 0 0 0];
activetagets = [1 1 1 1 1 1 1 1];
% 去多径+测呼吸初始化
Buffer = [];
% 视频输出设置
videoFile = 'output_track.mp4';  % 保存文件名
v = VideoWriter(videoFile, 'MPEG-4');  % 使用 MPEG-4 编码生成 MP4 文件
v.FrameRate = 10;  % 根据雷达帧率设置
open(v);

%% 实时处理
for jframe = 1:FrameNum
    frameStartTime = tic;
    %% 1dFFT to RD map
    oneFrame = mergedData(jframe, :, :, :);
    % 1dfft
    ifft1dData = ifft(oneFrame, [], 4);
    fft1dData = fft1dwindow(ifft1dData, p.fft1dwindowType, p.Nfft);
    fft1dData(:,:,:,UsefulSampleNum:end) = [];
    % MTI
    % MTIdata = MTI(fft1dData, p.MTIType);
    MTIdata = fft1dData;
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
            ekfinput = frame_dbscan(observations_filterd, 0.4, 1);
            ekfinput = ekfinput(:, 2:5);
        else, ekfinput = [];
        end
    end
    if ~isempty(ekfinput)
        set(hPoint, 'XData', ekfinput(:,1), 'YData', ekfinput(:,2));
    end
    %% 轨迹跟踪
    targets = tracks_ultra(ekfinput ,p);
    % activetagets[轨迹id x y state R G B num]
    [activetagets, colorIndex] = updateTracks(targets, jframe, p, colorIndex, draw);

    %% 人员状态更新
    if ~isempty(activetagets)
        [Person, activePersonList] = updatePersonStates(Person, activetagets, fft1dData, axis_info, p);
        if mod(jframe,30) == 1
            %% 绘制表格
            hTextList = drawPersonStatusTable(axTrack, activePersonList, hTextList);
        end
    end

    drawnow limitrate;
    frame = getframe(figure(1));  % 或 gcf
    writeVideo(v, frame);
    frameTimeBuffer = updateFrameRate(frameStartTime, frameTimeBuffer, frameTimeBufferSize, hFrameRateText);
    % figure(2);subplot(221);imagesc(abs(squeeze(fft1dData(:,:,1,:))));
    % subplot(222);imagesc(abs(squeeze(MTIdata(:,:,1,:))));
    % subplot(223);imagesc(abs(squeeze(fft2dData(:,:,1,:))));
    % subplot(224);imagesc(abs(squeeze(DNdata)));

end
close(v);
