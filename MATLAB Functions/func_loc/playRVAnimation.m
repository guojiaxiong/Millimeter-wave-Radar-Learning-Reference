function playRVAnimation(dopplerFFT, axis_info, varargin)
% PLAYRVANIMATION 带播放条的RV图动态播放函数（上下双图布局，无重叠）
% 用法:
%   playRVAnimation(dopplerFFT, axis_info)          % 默认帧率：10帧/秒
%   playRVAnimation(dopplerFFT, axis_info, fps)    % 自定义帧率（如5表示5帧/秒）
% 输入参数:
%   dopplerFFT   - 任意维度的雷达Doppler FFT数据（第一维度为帧维度）
%   axis_info    - 坐标轴信息结构体，需包含：
%                  axis_info.velocity: 速度轴向量 [ChirpNum×1]
%                  axis_info.range:    距离轴向量 [SampleNum×1]
%   fps          - 可选，播放帧率（帧/秒），默认10

% -------------------------- 输入参数处理 & 校验 --------------------------
fps = 10; % 默认帧率
period = 1/fps; % 定时器周期（秒/帧）

% 输入合法性校验
if isempty(dopplerFFT)
    error('dopplerFFT数据不能为空！');
end

% -------------------------- 预处理 --------------------------
dopplerFFT_abs = abs(dopplerFFT);   % 提前计算幅值，避免重复计算
totalFrames = size(dopplerFFT, 1);  % 总帧数（第一维度）
currentFrame = 1;                   % 初始帧

% -------------------------- 创建唯一播放窗口 & 上下子轴（核心修正：布局） --------------------------
% 1. 主窗口（仅创建一次）
fig = figure('Name', 'RV图动态播放（上下双图）', ...
    'Position', [100, 100, 900, 800], ...
    'DeleteFcn', @(~,~) cleanUp);   % 窗口关闭时清理定时器

% 2. 上下子轴（严格分开，无重叠）
% 上子轴：imagesc（占窗口上半部分，留出播放条空间）
ax1 = subplot(2,1,1, 'Parent', fig);  
set(ax1, 'Position', [0.1, 0.55, 0.8, 0.35]); % [左, 下, 宽, 高] - 上半部分
% 下子轴：mesh（占窗口中下部，播放条在最底部）
ax2 = subplot(2,1,2, 'Parent', fig);  
set(ax2, 'Position', [0.1, 0.15, 0.8, 0.35]); % [左, 下, 宽, 高] - 下半部分

% 3. 播放控制组件（窗口最底部，不遮挡子图）
% 3.1 播放条（滑块）
slider = uicontrol('Parent', fig, 'Style', 'slider', ...
    'Position', [100, 50, 700, 30], ... % 位置下移，避免遮挡下子图
    'Min', 1, 'Max', totalFrames, 'Value', currentFrame, ...
    'SliderStep', [1/totalFrames, min(10/totalFrames, 1)], ...
    'Callback', @(~,~) updateFrameBySlider);

% 3.2 帧号显示
txtFrame = uicontrol('Parent', fig, 'Style', 'text', ...
    'Position', [420, 10, 100, 30], ... % 最底部
    'String', sprintf('第%d帧 / 共%d帧', currentFrame, totalFrames));

% 3.3 开始/暂停按钮
btnPlay = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
    'Position', [200, 10, 100, 30], ... % 最底部
    'String', '开始播放', ...
    'Callback', @togglePlayback);

% 3.4 停止按钮
btnStop = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
    'Position', [600, 10, 100, 30], ... % 最底部
    'String', '停止播放', ...
    'Callback', @stopPlayback);

% 4. 自动播放定时器（核心控制帧率，避免堆积）
playbackTimer = timer('ExecutionMode', 'fixedRate', ...
    'Period', period, ...
    'TimerFcn', @updateFrameByTimer, ...
    'BusyMode', 'drop');
isPlaying = false; % 播放状态标记

% -------------------------- 初始绘制第一帧 --------------------------
updateFrame(currentFrame);

% ========================== 核心回调函数（上下双图，无重叠） ==========================
    % 函数1：更新指定帧的绘图（核心：上下子图严格分开）
    function updateFrame(frameIdx)
        % 1. 边界校验
        frameIdx = max(1, min(frameIdx, totalFrames));
        currentFrame = frameIdx;

        % 2. 提取当前帧数据（匹配[ChirpNum x SampleNum]格式）
        currentData = squeeze(dopplerFFT_abs(currentFrame,  :, :));
        [ChirpNum, SampleNum] = size(currentData);

        % 3. 维度校验（匹配axis_info）
        if length(axis_info.range) ~= SampleNum || length(axis_info.velocity) ~= ChirpNum
            error('数据维度与轴信息不匹配！数据[%d×%d]，速度轴长度=%d，距离轴长度=%d', ...
                ChirpNum, SampleNum, length(axis_info.velocity), length(axis_info.range));
        end

        % 4. 上子轴：imagesc（纯2D热力图，独立上区域）
        cla(ax1); % 仅清空上子轴内容，不删除轴
        imagesc(ax1, axis_info.velocity, axis_info.range, abs(currentData).');
        set(ax1, 'YDir', 'normal'); % Y轴从下到上（等价于axis xy）
        xlabel(ax1, 'Velocity(m/s)');
        ylabel(ax1, 'Range (m)');
        title(ax1, sprintf('Range-Velocity 热力图（第%d帧 / 总%d帧）', currentFrame, totalFrames));
        colorbar(ax1);
        % ylim(ax1, [0 8]);
        box(ax1, 'on'); % 加边框，更清晰

        % 5. 下子轴：mesh（3D网格图，独立下区域）
        cla(ax2); % 仅清空下子轴内容，不删除轴
        mesh(ax2, axis_info.velocity, axis_info.range, abs(currentData).');
        set(ax2, 'YDir', 'normal');
        xlabel(ax2, 'Velocity(m/s)');
        ylabel(ax2, 'Range (m)');
        zlabel(ax2, 'Amplitude'); % 补充Z轴标签，更清晰
        title(ax2, 'Range-Velocity 3D网格图');
        colorbar(ax2);
        % ylim(ax2, [0 8]);
        box(ax2, 'on');

        % 6. 强制刷新 + 更新播放控件
        drawnow;
        set(slider, 'Value', currentFrame);
        set(txtFrame, 'String', sprintf('第%d帧 / 共%d帧', currentFrame, totalFrames));
    end

    % 函数2：拖动滑块更新帧
    function updateFrameBySlider()
        frameIdx = round(get(slider, 'Value'));
        updateFrame(frameIdx);
    end

    % 函数3：定时器自动播放（逐帧更新，上下图同步）
    function updateFrameByTimer(~,~)
        frameIdx = round(get(slider, 'Value')) + 1;
        if frameIdx > totalFrames % 播放到最后一帧停止
            stopPlayback();
            frameIdx = 1; % 回到第一帧（可选，注释则停在最后一帧）
        end
        updateFrame(frameIdx);
    end

    % 函数4：切换播放/暂停
    function togglePlayback(~,~)
        if ~isPlaying
            isPlaying = true;
            start(playbackTimer);
            set(btnPlay, 'String', '暂停播放');
        else
            isPlaying = false;
            stop(playbackTimer);
            set(btnPlay, 'String', '开始播放');
        end
    end

    % 函数5：停止播放（重置到第一帧）
    function stopPlayback(~,~)
        isPlaying = false;
        stop(playbackTimer);
        set(btnPlay, 'String', '开始播放');
        updateFrame(1);
    end

    % 函数6：窗口关闭时清理资源
    function cleanUp()
        if isvalid(playbackTimer)
            stop(playbackTimer);
            delete(playbackTimer);
        end
        disp('播放窗口已关闭，资源已清理！');
    end
% ========================== 回调函数结束 ==========================

end