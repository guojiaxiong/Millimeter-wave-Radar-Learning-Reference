function Cancel_PulseCompre_Data = MTI(fftData, mtiModel, mtiDim)
% MTI 通用型动目标显示(MTI)杂波抵消函数（支持任意维度数据）
% 用法:
%   Cancel_PulseCompre_Data = MTI(fftData, cancelFlag, mtiDim)
% 输入参数:
%   fftData         - 任意维度的雷达复数/幅值数据（如4维[Frame, Chirp, Rx, Sample]）
%   mtiModel        - MTI抵消模式，支持：
%                     1 - 均值抵消（移除直流分量）
%                     2 - 双脉冲抵消
%                     3 - 三脉冲抵消
%   mtiDim          - 执行MTI抵消的目标维度
% 输出参数:
%   Cancel_PulseCompre_Data - MTI杂波抵消后的数据，维度与输入完全一致

% 1. 基础参数提取与合法性校验
dataDims = size(fftData);       % 获取输入数据维度
dimNum = length(dataDims);      % 数据总维度数
mtiDimLen = dataDims(mtiDim);   % 目标维度的长度

% 校验目标维度是否合法
if mtiDim < 1 || mtiDim > dimNum
    error('MTI目标维度%d超出数据维度范围（1~%d）', mtiDim, dimNum);
end
% 校验抵消模式是否合法
if ~ismember(mtiModel, [1,2,3])
    error('MTI抵消模式%d不合法，仅支持1(均值)/2(双脉冲)/3(三脉冲)', mtiModel);
end

% 2. 定义MTI模式常量
meanCancelMode = 1;
twoPulseMode = 2;
threePulseMode = 3;

% 3. 核心MTI杂波抵消逻辑
switch mtiModel
    case meanCancelMode
        % 均值抵消：减去目标维度的均值，直接适配任意维度
        Cancel_PulseCompre_Data = fftData - mean(fftData, mtiDim);

    case twoPulseMode
        % 双脉冲抵消：x(n) - x(n-1)，需保证目标维度长度≥2
        if mtiDimLen < 2
            warning('双脉冲抵消要求目标维度长度≥2，当前长度=%d，返回原数据', mtiDimLen);
            Cancel_PulseCompre_Data = fftData;
            return;
        end
        % 构造任意维度通用索引
        idxCurr = repmat({':'}, 1, dimNum);
        idxCurr{mtiDim} = 2:mtiDimLen;   % 当前帧索引
        idxPrev = repmat({':'}, 1, dimNum);
        idxPrev{mtiDim} = 1:mtiDimLen-1; % 前一帧索引
        % 双脉冲计算
        mtiResult = fftData(idxCurr{:}) - fftData(idxPrev{:});
        % 补全最后1个值，保证输出维度与输入一致
        idxPad = repmat({':'}, 1, dimNum);
        idxPad{mtiDim} = mtiDimLen;
        padVal = fftData(idxPad{:});
        Cancel_PulseCompre_Data = cat(mtiDim, mtiResult, padVal);

    case threePulseMode
        % 三脉冲抵消：x(n) - 2*x(n+1) + x(n+2)，需保证目标维度长度≥3
        if mtiDimLen < 3
            warning('三脉冲抵消要求目标维度长度≥3，当前长度=%d，返回原数据', mtiDimLen);
            Cancel_PulseCompre_Data = fftData;
            return;
        end
        % 构造任意维度通用索引
        idx1 = repmat({':'}, 1, dimNum);
        idx1{mtiDim} = 1:mtiDimLen-2;
        idx2 = repmat({':'}, 1, dimNum);
        idx2{mtiDim} = 2:mtiDimLen-1;
        idx3 = repmat({':'}, 1, dimNum);
        idx3{mtiDim} = 3:mtiDimLen;
        % 三脉冲计算
        mtiResult = fftData(idx1{:}) - 2 * fftData(idx2{:}) + fftData(idx3{:});
        % 补全最后2个值，保证输出维度与输入一致
        idxPad1 = repmat({':'}, 1, dimNum);
        idxPad1{mtiDim} = mtiDimLen-1;
        padVal1 = fftData(idxPad1{:});
        idxPad2 = repmat({':'}, 1, dimNum);
        idxPad2{mtiDim} = mtiDimLen;
        padVal2 = fftData(idxPad2{:});
        Cancel_PulseCompre_Data = cat(mtiDim, mtiResult, padVal1, padVal2);
end

% 4. 兜底校验：确保输出维度与输入完全一致
if ~isequal(size(Cancel_PulseCompre_Data), dataDims)
    error('MTI处理后维度异常，输入维度=%s，输出维度=%s', mat2str(dataDims), mat2str(size(Cancel_PulseCompre_Data)));
end

end