% function main()
%     % ======== 用户参数 ========
%     port           = "COM5";  % 串口号
%     chirpsPerFrame = 64;      % 每帧 chirp 数
%     chirpIdxShow   = 32;      % 可视化时选看的 chirp 序号 (1‑based)
%     drawEveryN     = 1;       % 每 N 帧更新一次曲线，可减小 UI 压力
%     % ==========================
% 
%     % 初始化雷达串口读取类
%     rdr = read_Raw_serial(port, chirpsPerFrame);
% 
%     % 生成图像窗口（仅创建一次，后续复用）
%     hFig = figure('Name', 'Raw Amplitude Curve', ...
%                   'NumberTitle', 'off', ...
%                   'Color', 'w');
%     grid on; hold on;
%     xlabel('Sample Index'); ylabel('Amplitude');
%     title(sprintf('Chirp %d  Raw Amplitude', chirpIdxShow));
%     lgd = legend('show');
%     % 先占位曲线
%     pRx0 = plot(NaN, NaN, '-b', 'DisplayName', 'Rx0 - Amp');
%     pRx1 = plot(NaN, NaN, '-r', 'DisplayName', 'Rx1 - Amp');
%     drawnow;
% 
%     frameCnt = 0;
%     while ishandle(hFig)
%         tStart = tic;
% 
%         % ---- 读一帧 ----
%         [rx0Cell, rx1Cell, ~, hasMore] = rdr.readFrame();
%         if ~hasMore
%             disp("数据读取完毕，退出循环");  break;
%         end
%         frameCnt = frameCnt + 1;
% 
%         % ---- 提取指定 chirp ----
%         if chirpIdxShow > numel(rx0Cell)
%             warning("chirpIdxShow 超出范围，本帧跳过可视化");
%         else
%             sig0 = rx0Cell{chirpIdxShow};
%             sig1 = rx1Cell{chirpIdxShow};
%             N    = numel(sig0);
%             if mod(frameCnt, drawEveryN) == 0
%                 set(pRx0, 'XData', 0:N-1, 'YData', abs(sig0));
%                 set(pRx1, 'XData', 0:N-1, 'YData', abs(sig1));
%                 title(sprintf('Frame %d   |   Chirp %d', frameCnt, chirpIdxShow));
%                 drawnow limitrate;
%             end
%         end
% 
%         fprintf('Frame %-5d  耗时 %.4f s\n', frameCnt, toc(tStart));
%     end
% 
%     % 关闭串口
%     rdr.close();
%     disp("程序结束，串口已关闭");
% end
% 
function main()
    % ======== 用户参数 ========
    port           = "COM5";  % 串口号
    chirpsPerFrame = 64;      % 每帧 chirp 数
    N              = 10;     % 要读取的帧数
    % ==========================

    % 初始化雷达串口读取类
    rdr = read_Raw_serial(port, chirpsPerFrame);

    % 记录开始时间
    tStart = tic;

    % 读取并合并 N 帧数据
    mergedData = rdr.readNFramesAndMerge(N);

    % 记录结束时间
    elapsedTime = toc(tStart);

    % 计算帧率
    frameRate = N / elapsedTime;  % 帧率 (FPS)

    % 处理合并后的数据
    disp('数据已合并');
    disp(size(mergedData));  % 输出维度
    disp(['处理时间: ', num2str(elapsedTime), ' 秒']);
    disp(['帧率: ', num2str(frameRate), ' 帧/秒']);
    
    % 关闭串口
    rdr.close();
    disp("程序结束，串口已关闭");
end
