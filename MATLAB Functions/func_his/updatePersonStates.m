function [Person, activePersonList] = updatePersonStates(Person, activetagets, fft1dData, axis_info, p)
% 更新 Person 状态，缓存静止数据并计算呼吸/心率
%
% 输入参数：
%   Person        - 所有目标的结构体数组
%   activetagets  - 当前帧检测到的目标 [id, x, y, state, R, G, B]
%   fft1dData     - 当前帧 FFT1D 数据（N个chirp, N个Rx, N个range bin）
%   axis_info     - 雷达参数结构体，包含 range 信息
%   p             - 参数结构体，需包含 frameTime 和 MAX_target/N_target
%
% 输出参数：
%   Person            - 更新后的全体结构体数组
%   activePersonList  - 当前帧激活的目标（用于绘图或显示表格）

ii = 1;
for i = 1:100
    % 查找当前 ID 是否在 activetagets 中
    idx = find(activetagets(:,1) == i, 1);
    if ~isempty(idx)
        % 检测到目标，更新状态
        Person(i).Color = activetagets(idx, 5:7);
        Person(i).S     = activetagets(idx, 4);  % 状态
        x = activetagets(idx, 2);
        y = activetagets(idx, 3);
        Person(i).R     = sqrt(x^2 + y^2);

        if Person(i).S == 1  % 静止
            Person(i).T = Person(i).T + 1;
            Person(i).Data = cat(1, Person(i).Data, fft1dData);
        else
            Person(i).T = 0;
            Person(i).Data = [];
        end

        % 添加到激活列表
        activePersonList(ii) = Person(i);
        ii = ii + 1;
    else
        % 没检测到目标，继续累加状态
        if Person(i).S == 1
            Person(i).T = Person(i).T + 1;
            Person(i).Data = cat(1, Person(i).Data, fft1dData);
        else
            Person(i).T = 0;
            Person(i).Data = [];
        end
    end

    % 若静止时间达到阈值，进行呼吸率检测
    if Person(i).T >= 50 && ~isempty(Person(i).Data)
        [~, minIdx] = min(abs(axis_info.range - Person(i).R));
        rangeBin = squeeze(Person(i).Data(:, 32, 1, minIdx));
        [Person(i).breathRate, Person(i).heartRate, ~] = get_heartBreath_rate(rangeBin, 1/p.frameTime);
        % 清空缓存
        Person(i).S = 0;
        Person(i).T = 0;
        Person(i).Data = [];
    end
end
end
