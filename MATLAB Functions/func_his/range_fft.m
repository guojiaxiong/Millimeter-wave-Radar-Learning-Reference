function rangeFFTProcessing()
    % 设置雷达参数 - 这些需要根据您的实际雷达参数进行调整
    c = 3e8;                 % 光速 (m/s)
    fc = 24e9;               % 载波频率 (Hz), 24GHz
    B = 0.22e9;                 % 带宽 (Hz), 假设为0.22GHz
    T = 420e-6;                % chirp时间 (s), 假设为0.42ms
    fs = 0.625e6;                % 采样频率 (Hz), 假设为2.5/4 MHz ，因为是每隔4个点取一个点
    
    % 距离分辨率计算
    rangeResolution = c / (2 * B);
    disp(['距离分辨率: ', num2str(rangeResolution), ' m']);
    
    % 最大无模糊距离计算
    maxRange = c * fs / (2 *  (B /T));
    disp(['最大检测距离: ', num2str(maxRange), ' m']);
    
    % 设置数据文件路径
    filename = 'data.dat';
    
    % 创建figure用于显示
    figRange = figure('Name', '距离谱', 'NumberTitle', 'off');
    
    % 初始化文件处理位置
    currentPosition = 0;
    chirpCounter = 0;
    
    % 循环读取每个chirp数据并处理
    hasMoreData = true;
    
    fprintf('开始逐chirp解析雷达数据并进行距离FFT...\n');
    
    % 创建一个矩阵来存储RDM (Range-Doppler Map)的历史数据
    numChirpsToProcess = 32;  % 可以调整处理的chirp数量
    rangeFFTSize = 512;       % 可以调整FFT点数
    
    % 预分配存储空间
    rx0RangePlot = zeros(rangeFFTSize/2, numChirpsToProcess);
    rx1RangePlot = zeros(rangeFFTSize/2, numChirpsToProcess);
    allRangeProfiles = cell(numChirpsToProcess, 2);  % 存储所有距离剖面
    
    while hasMoreData && chirpCounter < numChirpsToProcess
        % 读取下一个chirp数据
        [rx0Data, rx1Data, chirpCount, hasMoreData, currentPosition] = ...
            parseRadarData(filename, currentPosition);
        
        % 检查是否成功提取了数据
        if ~hasMoreData && isempty(rx0Data) && isempty(rx1Data)
            if chirpCounter == 0
                fprintf('未能提取任何有效数据，程序终止\n');
            else
                fprintf('所有数据处理完毕，共处理了 %d 个chirp\n', chirpCounter);
            end
            break;
        end
        
        % 更新chirp计数
        chirpCounter = chirpCounter + 1;
        
        % 打印当前处理的chirp信息
        fprintf('\n正在处理第 %d 个chirp (序号=%d)\n', ...
            chirpCounter, chirpCount);
        
        % 进行距离维FFT
        [rangeProfile_rx0, rangeProfile_rx1, rangeAxis] = calculateRangeProfile(rx0Data, rx1Data, rangeFFTSize, c, B);
        
        % 存储距离剖面
        allRangeProfiles{chirpCounter, 1} = rangeProfile_rx0;
        allRangeProfiles{chirpCounter, 2} = rangeProfile_rx1;
        
        % 更新距离图
        rx0RangePlot(:, chirpCounter) = rangeProfile_rx0;
        rx1RangePlot(:, chirpCounter) = rangeProfile_rx1;
        
        % 绘制当前chirp的距离谱
        figure(figRange);
        clf(figRange); % 清除当前图形内容
        
        subplot(2, 1, 1);
        plot(rangeAxis, 20*log10(abs(rangeProfile_rx0)), 'b-', 'LineWidth', 2);
        hold on;
        plot(rangeAxis, 20*log10(abs(rangeProfile_rx1)), 'r-', 'LineWidth', 2);
        hold off;
        title(['第 ', num2str(chirpCount), ' chirp的距离谱']);
        xlabel('距离 (m)');
        ylabel('幅度 (dB)');
        grid on;
        legend('RX0', 'RX1');
        
        % 显示2D距离-帧图
        subplot(2, 1, 2);
        
        % 合并两个接收通道的数据 (简单求和)
        combinedRange = 20*log10(abs(rx0RangePlot(:, 1:chirpCounter) + rx1RangePlot(:, 1:chirpCounter)));
        
        % 裁剪动态范围，改善可视化效果
        dynamicRange = 40;  % dB
        maxVal = max(combinedRange(:));
        combinedRange = max(combinedRange, maxVal - dynamicRange);
        
        imagesc(1:chirpCounter, rangeAxis, combinedRange);
        title('距离-帧图（累积）');
        xlabel('帧序号');
        ylabel('距离 (m)');
        colorbar;
        axis xy;  % y轴从下到上为正
        
        % 适当调整子图布局
        drawnow;
        
        % 如果还有更多数据，等待用户按键继续处理下一个chirp
        if hasMoreData && chirpCounter < numChirpsToProcess
            fprintf('\n按任意键继续处理下一个chirp的数据，或按Ctrl+C退出...\n');
            pause;
        end
    end
    
    % 处理结束后，显示累积结果
    if chirpCounter > 0
        figure('Name', '累积距离剖面', 'NumberTitle', 'off');
        
        % 计算所有帧的平均距离剖面
        meanRangeProfile_rx0 = zeros(size(rangeProfile_rx0));
        meanRangeProfile_rx1 = zeros(size(rangeProfile_rx1));
        
        for i = 1:chirpCounter
            meanRangeProfile_rx0 = meanRangeProfile_rx0 + allRangeProfiles{i, 1};
            meanRangeProfile_rx1 = meanRangeProfile_rx1 + allRangeProfiles{i, 2};
        end
        
        meanRangeProfile_rx0 = meanRangeProfile_rx0 / chirpCounter;
        meanRangeProfile_rx1 = meanRangeProfile_rx1 / chirpCounter;
        
        % 显示平均距离剖面
        plot(rangeAxis, 20*log10(abs(meanRangeProfile_rx0)), 'b-', 'LineWidth', 2);
        hold on;
        plot(rangeAxis, 20*log10(abs(meanRangeProfile_rx1)), 'r-', 'LineWidth', 2);
        plot(rangeAxis, 20*log10(abs(meanRangeProfile_rx0 + meanRangeProfile_rx1)), 'g-', 'LineWidth', 2);
        hold off;
        
        title(['平均距离剖面 (', num2str(chirpCounter), ' 帧)']);
        xlabel('距离 (m)');
        ylabel('幅度 (dB)');
        grid on;
        legend('RX0', 'RX1', 'RX0+RX1');
        
        % 分析在哪个距离处有峰值
        [combinedProfile, peakIndices] = findPeaksInRangeProfile(meanRangeProfile_rx0 + meanRangeProfile_rx1, rangeAxis);
        
        % 显示检测到的目标
        fprintf('\n检测到的目标:\n');
        for i = 1:length(peakIndices)
            fprintf('目标 #%d: 距离 = %.2f m, 幅度 = %.2f dB\n', ...
                i, rangeAxis(peakIndices(i)), 20*log10(abs(combinedProfile(peakIndices(i)))));
        end
    end
end

function [rangeProfile_rx0, rangeProfile_rx1, rangeAxis] = calculateRangeProfile(rx0Data, rx1Data, rangeFFTSize, c, B)
    % 处理RX0数据
    if ~isempty(rx0Data)
        % 应用窗函数减少旁瓣
        win = hamming(length(rx0Data));
        rx0Data_win = rx0Data .* win;
        
        % 执行距离FFT
        rangeFFT_rx0 = fft(rx0Data_win, rangeFFTSize);
        
        % 只保留一半的FFT结果（由于实信号的FFT是对称的）
        rangeProfile_rx0 = rangeFFT_rx0(1:rangeFFTSize/2);
    else
        rangeProfile_rx0 = zeros(rangeFFTSize/2, 1);
    end
    
    % 处理RX1数据
    if ~isempty(rx1Data)
        % 应用窗函数减少旁瓣
        win = hamming(length(rx1Data));
        rx1Data_win = rx1Data .* win;
        
        % 执行距离FFT
        rangeFFT_rx1 = fft(rx1Data_win, rangeFFTSize);
        
        % 只保留一半的FFT结果
        rangeProfile_rx1 = rangeFFT_rx1(1:rangeFFTSize/2);
    else
        rangeProfile_rx1 = zeros(rangeFFTSize/2, 1);
    end
    
    % 计算距离轴
    rangeAxis = (0:rangeFFTSize/2-1) * c / (2 * B);
end

function [combinedProfile, peakIndices] = findPeaksInRangeProfile(rangeProfile, rangeAxis)
    % 计算幅度
    amplitudeProfile = abs(rangeProfile);
    combinedProfile = rangeProfile;
    
    % 转换为dB
    amplitudeProfile_dB = 20*log10(amplitudeProfile);
    
    % 找到峰值 (使用findpeaks函数)
    % 设置最小峰值高度和最小峰值距离
    minPeakHeight = max(amplitudeProfile_dB) - 15;  % 比最大值小15dB以内
    minPeakDistance = 10;  % 最小峰值之间的距离（采样点）
    
    [~, peakIndices] = findpeaks(amplitudeProfile_dB, ...
        'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    
    % 过滤近距离杂波 (例如，距离小于0.5m的信号)
    nearIndices = rangeAxis < 0.5;
    validPeaks = [];
    for i = 1:length(peakIndices)
        if ~nearIndices(peakIndices(i))
            validPeaks = [validPeaks, peakIndices(i)];
        end
    end
    
    peakIndices = validPeaks;
end

% 解析雷达数据的函数 (使用上面提供的parseRadarData函数)