function DoA = estimateDoA(cfarIdx, p, fft2dData)
% 使用指定 DOA 方法计算目标方向
% 输入:
%   cfarIdx    : [N x 3]，每行 [frameIdx, dopplerIdx, rangeIdx]
%   p          : 参数结构体，包含 DOA 所需配置
%   fft2dData  : 四维矩阵 [frame, doppler, antenna, range]
% 输出:
%   DoAfiltered: [N x 2]，每一帧的估计角度 (单位：度)
    N = size(cfarIdx, 1);
    DoA = zeros(N, 2);
    DoA(:, 1) = cfarIdx(:, 1);
    for f = 1:N
        frameIdx   = cfarIdx(f, 1);
        dopplerIdx = cfarIdx(f, 2);
        rangeIdx   = cfarIdx(f, 3);

        antVec = squeeze(fft2dData(frameIdx, dopplerIdx, :, rangeIdx));
        [angle, ~] = doa(p, antVec);
        DoA(f, 2) = angle;
    end
end
