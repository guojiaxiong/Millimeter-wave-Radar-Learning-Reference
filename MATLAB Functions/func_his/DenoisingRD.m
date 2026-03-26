function DNdata = DenoisingRD(lossR, lossD, axis_info, Data)
%
% 输入:
%   lossF        - 起始损耗阈值 (dB)
%   Data    - RD，维度为 [FrameNum × ChirpNum × SampleNum]
%
% 输出:
%   DNdata - 经损失门限滤波后的数据

% R维
lossline = linspace(lossR, lossR-12, length(axis_info.range));  % [1 × SampleNum]
lossline3D = reshape(lossline, [1, 1, length(lossline)]);   % 扩展为 4D
mask = db(Data) < lossline3D;
DNdata = Data;
DNdata(mask) = 1;

% D维
mask = abs(axis_info.velocity) < lossD;
DNdata(:, mask, :) = 1;


disp('Denoising done.');

end
