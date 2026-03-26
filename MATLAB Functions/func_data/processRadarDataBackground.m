function processRadarDataBackground(dataQueue, p)
    % 在独立的工作进程中处理雷达数据
       % 当前参数
    try
        % 初始化雷达串口读取类
        rdr = read_Raw_serial(p.port, p.Chirps);
        frameCnt = 0;
        while true
            tStart = tic;
            % 读取一帧数据
            [rx0Cell, rx1Cell, ~, hasMore] = rdr.readFrame();
            if ~hasMore
                % 发送结束信号
                endData = struct();
                endData.finished = true;
                endData.message = '数据读取完毕';
                send(dataQueue, endData);
                break;
            end
            
            frameCnt = frameCnt + 1;
            
            % 处理雷达数据并检测目标
            targets = processRadarAndDetectTargets(rx0Cell, rx1Cell, p);

            % 准备发送的数据结构
            sendData = struct();
            sendData.frameCnt = frameCnt;
            sendData.processTime = toc(tStart);
            sendData.currentParams = p;
            sendData.targets = targets;

            % 发送数据到主线程
            send(dataQueue, sendData);
        end
        
        % 关闭串口
        rdr.close();
        
    catch ME
        % 发送错误信息
        errorData = struct();
        errorData.error = true;
        errorData.message = ME.message;
        send(dataQueue, errorData);
        
        % 尝试关闭串口
        if exist('rdr', 'var')
            try
                rdr.close();
            catch
                % 忽略关闭错误
            end
        end
    end
end

function targets = processRadarAndDetectTargets(rx0Cell, rx1Cell, p)
    % 完整的雷达信号处理和目标检测流程
    targets = [];

    try
        % read data
        frameData = zeros(1, p.Chirps, 2, p.Samples);
        for c = 1:p.Chirps
            frameData(1, c, 1, :) = rx0Cell{c};
            frameData(1, c, 2, :) = rx1Cell{c};
        end
        
        % axis
        axis_info = setaxis(p);
        % axis cut
        UsefulSampleNum = find(axis_info.range>p.rangecut, 1);
        axis_info.range(UsefulSampleNum:end) = [];
        UsefulChirpNumF = find(axis_info.velocity<-p.velocitycut, 1, 'last');
        UsefulChirpNumL = find(axis_info.velocity>p.velocitycut, 1, "first");
        axis_info.velocity([1:UsefulChirpNumF, UsefulChirpNumL:p.Chirps * p.Nfft]) = [];
        % 1dfft
        fft1dData = fft1dwindow(frameData, p.fft1dwindowType, p.Nfft);
        % range cut
        fft1dData(:,:,:,UsefulSampleNum:end) = [];
        % MTI
        fft1d_MTI = MTI(fft1dData, p.MTIType);
        % Denoising
        fft1d_Denoising = DenoisingLT(p.lossF, axis_info, fft1d_MTI);
        % DopplerFFT
        fft2dData = fft2dwindow(fft1d_Denoising, p.fft2dwindowType, p.Nfft);
        % velocity cut
        fft2dData(:,[1:UsefulChirpNumF, UsefulChirpNumL:p.Chirps * p.Nfft],:,:) = [];
        % NCA
        dataNca = squeeze(sum(fft2dData, 3));
        disp('NCA done.');
        % AAC
        dataAAC = applyAmplitudeCompensation(dataNca);
        % cfar
        RD_map = abs(dataAAC);
        [targetList, cfarIdx] = detectTopNTargets(RD_map, p.N_target, p.suppressWin, 1, p.energyThresh);
        
        if ~isempty(targetList)
            % 10. DBSCAN聚类（保持原逻辑）
            if size(targetList, 1) >= p.minPts && exist('dbscan', 'file')
                points = targetList(:, 1:2);
                [idx, isNoise] = dbscan(points, p.epsilon, p.minPts);
                
                if max(idx) > 0
                    centroids = [];
                    for i = 1:max(idx)
                        clusterPoints = points(idx == i, :);
                        centroid_vIdx = round(mean(clusterPoints(:, 1)));
                        centroid_rIdx = round(mean(clusterPoints(:, 2)));
                        
                        clusterIntensities = targetList(idx == i, 3);
                        avg_intensity = mean(clusterIntensities);
                        
                        centroids = [centroids; centroid_vIdx, centroid_rIdx, avg_intensity];
                    end
                    
                    if ~isempty(centroids)
                        targetList = centroids;
                        % 更新 cfarIdx 以匹配聚类后的目标
                        cfarIdx = [];
                        for i = 1:size(centroids, 1)
                            cfarIdx = [cfarIdx; 1, centroids(i, 1), centroids(i, 2)]; % frameIdx=1
                        end
                    end
                end
            end
            
            % 11. DOA估计 - 根据您的代码重新编写
            if params.DOA_flag > 0
                % 设置DOA方法
                p.doaMethod = params.DOA_flag; % [1 2 3] = [dbf fft capon]
                
                % 初始化DOA结果数组
                DoA = zeros(size(cfarIdx, 1), 2);
                DoA(:, 1) = cfarIdx(:, 1); % frameIdx (都是1)
                
                % 对每个检测到的目标进行DOA估计
                for f = 1:size(cfarIdx, 1)
                    frameIdx = cfarIdx(f, 1); % 应该是1
                    vIdx = cfarIdx(f, 2);     % 速度索引
                    rIdx = cfarIdx(f, 3);     % 距离索引
                    
                    % 确保索引在有效范围内
                    if frameIdx <= size(fft2dData, 1) && ...
                       vIdx <= size(fft2dData, 2) && ...
                       rIdx <= size(fft2dData, 4)
                        
                        % 提取天线数据 - 按照您的格式
                        ant = squeeze(fft2dData(frameIdx, vIdx, :, rIdx));
                        
                        % 调用DOA函数
                        [Angle, doa_abs] = doa(p, ant);
                        
                        % 存储角度结果
                        DoA(f, 2) = Angle;
                    else
                        % 索引超出范围，设置为0度
                        DoA(f, 2) = 0;
                    end
                end
                
                % DOA平滑（如果需要）
                DoAfiltered = DoA(:, 2);
                
                % 12. 转换为笛卡尔坐标
                for i = 1:size(targetList, 1)
                    vIdx = targetList(i, 1);
                    rIdx = targetList(i, 2);
                    intensity = targetList(i, 3);
                    
                    % 获取对应的角度
                    if i <= length(DoAfiltered)
                        Angle = DoAfiltered(i);
                    else
                        Angle = 0; % 默认角度
                    end
                    
                    % 获取距离和速度
                    if rIdx <= length(axis_info.range) && vIdx <= length(axis_info.velocity)
                        range = axis_info.range(rIdx);
                        velocity = axis_info.velocity(vIdx);
                        
                        % 检查角度和距离是否在有效范围内
                        if abs(Angle) <= 60 && range <= 8 && range > 0.5
                            % 转换为笛卡尔坐标
                            x = range * sind(Angle);
                            y = range * cosd(Angle);
                            
                            % 确保y > 0 (前向检测)
                            if y > 0
                                targets = [targets; x, y, intensity];
                            end
                        end
                    end
                end
            end
        % 13. 最终处理
        if ~isempty(targets)
            % 按强度排序
            [~, sortIdx] = sort(targets(:, 3), 'descend');
            targets = targets(sortIdx, :);
            
            % 限制目标数量
            max_targets = min(N_target, 20);
            if size(targets, 1) > max_targets
                targets = targets(1:max_targets, :);
            end
            
            % 去除重复目标
            targets = removeDuplicateTargets(targets, 0.3);
        end
        end

        % DOA
        DoA = estimateDoA(cfarIdx, p, fft2dData);

        % Position modeling 
        % observations = [x, y, vx, vy, range, theta]
        observations = PositionModel(cfarIdx, axis_info, DoA(:, 2));
        
% 
%         % track
%         observations = [cfarIdx(:, 1, :), observations(:, 1:4)];
        
        % xy2r
        
    catch ME
        fprintf('雷达数据处理错误: %s\n', ME.message);
        targets = [];
    end
end

% 辅助函数：去除重复目标
function uniqueTargets = removeDuplicateTargets(targets, distThreshold)
    if size(targets, 1) <= 1
        uniqueTargets = targets;
        return;
    end
    
    uniqueTargets = targets(1, :);
    
    for i = 2:size(targets, 1)
        currentTarget = targets(i, :);
        distances = sqrt(sum((uniqueTargets(:, 1:2) - currentTarget(1:2)).^2, 2));
        
        if all(distances > distThreshold)
            uniqueTargets = [uniqueTargets; currentTarget];
        end
    end
end

