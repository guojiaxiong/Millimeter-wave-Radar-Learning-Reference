function fft1d_Denoising = DenoisingLT(lossF, axis_info, fft1dData)
%
% 输入:
%   lossF        - 起始损耗阈值 (dB)
%   axis_info    - 包含 range 信息的结构体，要求 axis_info.range 为 [1 × SampleNum]
%   fft1dData    - 原始FFT数据，维度为 [FrameNum × ChirpNum × RxNum × SampleNum]
%
% 输出:
%   fft1d_Denoising - 经损失门限滤波后的数据，单位为 dB

% 构建自适应损失线
lossL = lossF - 12;
lossline = linspace(lossF, lossL, size(axis_info.range, 2));  % [1 × SampleNum]
lossline4D = reshape(lossline, [1, 1, 1, length(lossline)]);   % 扩展为 4D

fft1d_Denoising = (fft1dData);  % 大小 [F × C × Rx × S]

% 设置门限
gate = abs(max(fft1dData, [],'all'));
fft1d_dB = db(fft1dData);
mask = fft1d_dB < lossline4D;


% 应用门限
%     fft1d_Denoising(mask) = fft1d_Denoising(mask) ./ gate;
fft1d_Denoising(mask) = 1;
disp('Denoising done.');

end
