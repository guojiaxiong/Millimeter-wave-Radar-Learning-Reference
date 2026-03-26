function [mergedData] = getdata(p)
    % ======== 用户参数 ========
    port           = "COM5";  % 串口号
    chirpsPerFrame = 64;      % 每帧 chirp 数
    N              = p.frameWindow;     % 要读取的帧数
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
