function [targets,detection] = processRadarAndDetectTargets(rx0Cell, rx1Cell, p, frameCnt)
    % 完整的雷达信号处理和目标检测流程
    targets = [];
    detection=[];
    try
        % read data
        frameData = zeros(1, p.Chirps, 2, p.fftSamples);
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
        ifftData = ifft(frameData, [], 4);
        fft1dData = fft1dwindow(ifftData, p.fft1dwindowType, p.Nfft);
        fft1dData(:,:,:,UsefulSampleNum:end) = [];
        % MTI
        MTIdata = MTI(fft1dData, p.MTIType);
        % 2dfft
        fft2dData = fft2dwindow(MTIdata, p.fft2dwindowType, p.Nfft);
        fft2dData(:,[1:UsefulChirpNumF, UsefulChirpNumL:p.Chirps * p.Nfft],:,:) = [];
        % NCA
        NCAdata = squeeze(sum(fft2dData, 3));
        NCAdata = reshape(NCAdata, [1 size(NCAdata)]);
        % AAC
        AACdata = applyAmplitudeCompensation(NCAdata);
        % DN
        DNdata = DenoisingRD(p.lossR,p.lossD, axis_info, AACdata);   
        % cfar
        RD_map = squeeze(abs(DNdata));
        [targetList, cfarIdx] = detectTopNTargets(RD_map, p.N_target, p.suppressWin, 1, p.energyThresh);
        
        
        if ~isempty(targetList)
            % 10. DBSCAN聚类（保持原逻辑）
            if size(targetList, 1) >= p.minPts && exist('dbscan', 'file')
                points = targetList(:, 1:2);
                [idx, ~] = dbscan(points, p.epsilon, p.minPts);
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
%                         targetList = centroids;
                        % 更新 cfarIdx 以匹配聚类后的目标
                        cfarIdx = [];
                        for i = 1:size(centroids, 1)
                            cfarIdx = [cfarIdx; 1, centroids(i, 1), centroids(i, 2)]; % frameIdx=1
                        end
                    end
                end
            end
        end
        disp("dbscan done");
        if isempty(cfarIdx) 
            return;
        end
        % DOA
        DoA = estimateDoA(cfarIdx, p, fft2dData);
        % Position modeling 
        % observations = [x, y, vx, vy, range, theta]
        observations = PositionModel(cfarIdx, axis_info, DoA(:, 2));
        disp("PositionModel done");
        %直接提取cfar点
%         detection = observations(:,[2 3]);
        % 关联五帧数据用于聚类求平均得到的目标点
        targets = slidingWindowClustering(p.related_FrameNum, frameCnt, observations,p.epsilon1, p.minPoints1,p);
        if isempty(targets)
            disp("targets is empty");
            return;
        end
%         disp(targets);
        observations = targets;
        detection = targets(:,[2 3]);
        if p.reset == 0
        %当前帧的轨迹点  current_points = [track_id  x  y ]
            targets = tracks_ultra(observations(: , 2:5), p.costThreshold, p.predictionframe, p.reset);
        end
    catch ME
        fprintf('雷达数据处理错误: %s\n', ME.message);
        targets = [];
    end
end

