function dataAAC = applyAmplitudeCompensation(dataNca)
    % 获取数据的维度
    [FrameNum, n, m] = size(dataNca);  % FrameNum: 帧数，n: 速度维度，m: 距离维度
    powerad_range = linspace(0, 8, m);  % 距离维度的补偿系数
    powerad_range3d = repmat(reshape(powerad_range, [1, 1, m]), FrameNum,n);
    dataAAC = db(dataNca)+ powerad_range3d;
    dataAAC = 10.^(dataAAC / 20);

% %         % 生成速度方向的补偿系数，速度维度补偿从正中间为0开始，线性变化
% %         powerad_velocity = linspace(-5, 5, n);  % 速度维度的补偿系数，从-5到+5线性变化
% %         powerad_velocity2d = repmat(powerad_velocity', [1, m]);  % 将其扩展为与数据维度匹配    
%         % 对速度维度进行补偿
% %         X = X + powerad_velocity2d;  % 速度方向补偿

    disp('AAC done.');
end
